/// A monospace, selectable, copy-to-clipboard code view.
///
/// This is the "code" half of a [ShowcaseCell]: it presents the verbatim
/// instantiation snippet for a widget so a reader can copy it straight into
/// their own project. Kept deliberately framework-neutral (plain Material) so
/// the chrome never competes with the `tom_flutter_ui` widget on display.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Renders a Dart snippet in a bordered monospace panel with a copy button.
class CodeBlock extends StatelessWidget {
  const CodeBlock(this.code, {super.key});

  /// The verbatim Dart source that produced the sibling widget.
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
            child: SelectableText(
              trimmed,
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
            child: IconButton(
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
