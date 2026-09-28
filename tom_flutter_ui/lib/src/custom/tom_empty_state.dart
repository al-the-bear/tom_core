/// Standard placeholder for a view that loaded successfully and has
/// nothing to show — distinct from a loading state, which has not
/// finished, and from an error state, which failed.
///
/// A leaf widget with no bindings of its own: it is composed in by
/// whatever owns the list, wherever that owner decides "no rows" should
/// read as a designed surface rather than blank space.
///
/// Renders a vertically stacked icon + title + description + optional
/// action button. All strings flow through the resource provider when
/// the caller hands in a [TomEmptyState.tomId] (preferred) — fall-back
/// literals are also supported for ad-hoc usage in tests / one-off
/// screens.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../widget_base/tom_construction_helpers.dart';

/// Standard placeholder for empty data views.
class TomEmptyState extends StatelessWidget {
  /// Optional resource path for resolving `title`, `description`, and
  /// `actionLabel`. When provided, the widget reads
  /// `<basePath>.title`, `<basePath>.description`, and
  /// `<basePath>.actionLabel` (each falling back to the explicit
  /// parameters below).
  final String? tomId;

  /// Optional explicit scope override. When `null`, [TomScope.current]
  /// is used to qualify [tomId].
  final TomScope? scope;

  /// Icon shown above the headline. Defaults to a generic
  /// [Icons.inbox_outlined] glyph.
  final IconData icon;

  /// Headline. Genuinely required: supply this, a [tomId], or both.
  ///
  /// A `<basePath>.title` resource wins over this value when both are
  /// present. When a [tomId] is given but its resource is missing, the
  /// resource *key* is rendered — the same development signal every other
  /// Tom widget gives — so this parameter is the fallback for that case,
  /// not a second-class alternative to it.
  ///
  /// With neither source the constructor throws a [StateError] rather than
  /// leaving a wordless icon on screen. The throw is raised here, and not
  /// during `build`, so that it lands on the caller's own line instead of
  /// being caught by an enclosing `TomErrorBoundary` and rendered as a
  /// runtime error card.
  final String? title;

  /// Optional supporting copy beneath the headline.
  final String? description;

  /// Optional call-to-action button label. When set together with
  /// [onActionPressed], the widget renders an [ElevatedButton].
  final String? actionLabel;

  /// Handler invoked when the action button is tapped.
  final VoidCallback? onActionPressed;

  /// Diameter (logical pixels) of the icon. Defaults to 48.
  final double iconSize;

  /// Headline actually rendered — never null, by construction.
  late final String _resolvedTitle;

  /// Supporting copy actually rendered, or `null` when there is none.
  late final String? _resolvedDescription;

  /// Action label actually rendered, or `null` when there is none.
  late final String? _resolvedActionLabel;

  /// Not `const`: the headline is resolved here rather than in `build` so a
  /// missing headline reaches the caller instead of an error boundary. See
  /// [title].
  TomEmptyState({
    super.key,
    this.tomId,
    this.scope,
    this.icon = Icons.inbox_outlined,
    this.title,
    this.description,
    this.actionLabel,
    this.onActionPressed,
    this.iconSize = 48,
  }) {
    // `resolvePath` is documented as a call-once-per-widget operation, and
    // all three strings share the base path.
    final basePath = TomCtr.resolvePath(tomId, scope);

    /// Resources first, explicit second — the precedence this widget has
    /// always documented at [tomId], and the reverse of the button family's.
    ///
    /// One closure rather than the rule written out three times: the three
    /// strings differ only in their key and their fallback, and a precedence
    /// spelled out per string is a precedence that can drift per string.
    String? resolved(String key, String? explicit) =>
        TomCtr.textOrNull(basePath, key) ?? explicit;

    // `textOrFail` closes the headline's chain: it renders the key when a
    // tomId was given but its resource is absent, and throws when neither
    // source was. That is why the title cannot simply be `resolved(...)` —
    // it is the one of the three that may not come out null.
    _resolvedTitle =
        resolved('title', title) ?? TomCtr.textOrFail(basePath, 'title');
    _resolvedDescription = resolved('description', description);
    _resolvedActionLabel = resolved('actionLabel', actionLabel);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = _resolvedDescription;
    final actionText = _resolvedActionLabel;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              _resolvedTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.8,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionText != null && onActionPressed != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onActionPressed,
                child: Text(actionText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
