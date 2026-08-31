/// A monospace, selectable, copy-to-clipboard code view.
///
/// This is the "code" half of a [ShowcaseCell]: it presents the verbatim
/// instantiation snippet for a widget so a reader can copy it straight into
/// their own project. The chrome is styled to stay visually neutral — a
/// monospace [TomSelectableText] inside a bordered panel with a [TomIconButton]
/// copy affordance — so it never competes with the `tom_flutter_ui` widget on
/// display (G-UI-1: the sample's own UI is built from Tom* components too).
///
/// Shared in shape with `core_flutter_acl_sample` /
/// `core_flutter_acl_responsive` / `core_flutter_form_showcase`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Renders a Dart snippet in a bordered monospace panel with a copy button.
// Why: extends [TomStatelessWidget] so even the code panel is built on a Tom
// base (G-UI-1/G-UI-2). It has no tomId/resources, so a family base would be
// wrong; [TomStatelessWidget] is the sanctioned base for scope-participating
// chrome. Construction enters [TomScope.current] → the constructor is non-const.
class CodeBlock extends TomStatelessWidget {
  CodeBlock(this.code, {super.key});

  /// The verbatim Dart source that produced the sibling widget.
  final String code;

  @override
  Widget buildContent(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trimmed = code.trim();
    return TomDecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: TomStack(
        children: [
          TomPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 40, 12),
            child: TomSelectableText(
              text: trimmed,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
          TomPositioned(
            top: 2,
            right: 2,
            child: TomIconButton(
              icon: TomIcon(icon: Icons.copy, size: 16),
              // Interactive chrome, not a teaching snippet: resolved as a resource
              // per G-RES-1 (see chrome_texts.dart).
              tooltip: TomCtr.text('showcase.codeBlock.copyTooltip'),
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: trimmed)),
            ),
          ),
        ],
      ),
    );
  }
}
