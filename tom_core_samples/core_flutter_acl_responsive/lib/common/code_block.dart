/// A monospace, selectable, copy-to-clipboard code view.
///
/// This is the "code" half of a [ShowcaseCell]: it presents the verbatim
/// instantiation snippet for a responsive layout so a reader can copy it
/// straight into their own project. The chrome is styled to stay visually
/// neutral — a monospace [TomSelectableText] inside a bordered panel with a
/// [TomIconButton] copy affordance — so it never competes with the
/// `tom_flutter_ui` layout on display (G-UI-1). Shared in shape with the
/// sibling `core_flutter_form_showcase` / `core_flutter_acl_sample` samples.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Renders a Dart snippet in a bordered monospace panel with a copy button.
class CodeBlock extends StatelessWidget {
  const CodeBlock(this.code, {super.key});

  /// The verbatim Dart source that produced the sibling layout.
  final String code;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trimmed = code.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Stack(
        children: [
          Padding(
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
          Positioned(
            top: 2,
            right: 2,
            child: TomIconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: 'Copy snippet',
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: trimmed)),
            ),
          ),
        ],
      ),
    );
  }
}
