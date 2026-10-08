/// The defining piece of this sample: a cell that shows a responsive layout's
/// instantiation source *beside* the live, rendered layout.
///
/// The teaching value is the `code | rendered` pairing — a curated snippet of
/// the builder chain next to the layout it produces. Fittingly for a sample
/// *about* the responsive engine, the cell **dogfoods** that engine to lay
/// itself out: an [AclBuilder] row breakpoint keeps the snippet and the preview
/// side by side while the cell is at least 720px wide and reflows them to a
/// stack below it, rather than a hand-rolled `MediaQuery` compare (G-UI-4).
/// Shared in shape with `core_flutter_ui_showcase` /
/// `core_flutter_form_showcase` / `core_flutter_acl_sample`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'code_block.dart';

/// A single showcase entry: a [title], a curated [code] snippet, and the live
/// [child] layout that snippet illustrates. An optional [note] surfaces a
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
    this.childMinWidth,
  });

  /// Human-readable label for the mechanism being shown.
  final String title;

  /// A curated Dart snippet of the API [child] demonstrates, kept in step with
  /// [child] by hand.
  ///
  /// It is deliberately **not** a transcript of the live source. The child is
  /// wrapped in gallery harness — width pins, `FormHost` scaffolding, badge rows
  /// that make the behaviour observable and testable — which would bury the one
  /// call the cell is about; and paired cells such as wide/narrow carry only
  /// `// same chain, the width differs`, because repeating the chain is exactly
  /// what would hide their point. So a snippet may drop scaffolding, elide
  /// repetition behind a `…` comment, and use a short stand-in where the live
  /// code threads a gallery-specific id or variable.
  ///
  /// What it may not do is **name an API that does not exist**. That is the
  /// line between an abridgement and a lie, and it is the half a reader relies
  /// on when they lift a line into their own project.
  /// `showcase_cell_test.dart` holds both halves: every snippet is non-empty,
  /// and every constructor or method a snippet calls is also called by the live
  /// code in that group's own source.
  final String code;

  /// The live layout rendered from [code].
  final Widget child;

  /// Optional caveat shown under the title.
  final String? note;

  /// The narrowest width [child] has to be given to show what it demonstrates,
  /// when it has one.
  ///
  /// Most previews are elastic and leave this null. A cell whose subject is a
  /// width threshold declares it: side by side, the long lines of the snippet
  /// claim most of the row, and a preview squeezed below its threshold can
  /// never show the wide side of what it teaches. Declaring the width makes
  /// the split grant at least it, and makes the cell stack instead when the
  /// row is too narrow for both halves.
  final double? childMinWidth;

  /// What [_PreviewSurface] adds around [child]: its padding and border.
  static const double _previewFrame = 2 * (16 + 1);

  /// The narrowest code column worth splitting for. Below it the snippet wraps
  /// so hard that the side-by-side reading the cell exists for is lost.
  static const double _minCodeWidth = 280;

  /// The gutter between the two columns.
  static const double _gutter = 16;

  /// The cell width below which the `code | preview` pair stacks: 720, or
  /// wider when both halves need more — the preview's declared minimum, a
  /// readable code column and the gutter.
  double get _splitBelow => childMinWidth == null
      ? 720
      : math.max(720, childMinWidth! + _previewFrame + _minCodeWidth + _gutter);

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
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
            TomSizedBox(height: 12),
            // Dogfood the engine (G-UI-4): a sample *about* responsiveness lays
            // its own cells out with an AclBuilder row breakpoint instead of a
            // hand-rolled MediaQuery compare — code | preview share one row
            // while the cell is wide enough for both and reflow to a stack
            // below it. The ACL default top cross-alignment and its
            // intrinsic-free measurement keep previews that build an internal
            // LayoutBuilder — the ACL engine itself — robust.
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
        .addRowBreakpoint(atWidth: _splitBelow, splitRowDist: 12);
    final min = childMinWidth;
    if (min == null) {
      return builder.append(preview, dist: _gutter).build();
    }
    // Both columns expand, and each keeps its declared minimum as a floor:
    // the snippet a readable width, the preview the width it was declared to
    // need. Only the space beyond the two floors is shared between them, so
    // side by side the preview is never narrower than its minimum — and the
    // row breaks before that could not hold. Stacked, each column is alone in
    // its row and fills it.
    return builder
        .setMSize(_minCodeWidth)
        .append(preview, dist: _gutter)
        .setMSize(min + _previewFrame)
        .build();
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
      child: TomAlign(alignment: Alignment.centerLeft, child: child),
    );
  }
}
