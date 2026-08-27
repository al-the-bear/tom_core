/// Standard placeholder for empty data views. Used by `TomListForm`
/// when its bound list is empty, and any other "no data yet" surface.
///
/// Renders a vertically stacked icon + title + description + optional
/// action button. All strings flow through the resource provider when
/// the caller hands in a [tomId] (preferred) — fall-back literals are
/// also supported for ad-hoc usage in tests / one-off screens.
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

  /// Headline. Required when no [tomId] resolves a `title` resource.
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

  const TomEmptyState({
    super.key,
    this.tomId,
    this.scope,
    this.icon = Icons.inbox_outlined,
    this.title,
    this.description,
    this.actionLabel,
    this.onActionPressed,
    this.iconSize = 48,
  });

  String? _resolvedTitle() {
    if (tomId != null) {
      final basePath = TomCtr.resolvePath(tomId, scope);
      if (basePath != null) {
        final t = TomCtr.textOrNull(basePath, 'title');
        if (t != null) return t;
      }
    }
    return title;
  }

  String? _resolvedDescription() {
    if (tomId != null) {
      final basePath = TomCtr.resolvePath(tomId, scope);
      if (basePath != null) {
        final t = TomCtr.textOrNull(basePath, 'description');
        if (t != null) return t;
      }
    }
    return description;
  }

  String? _resolvedActionLabel() {
    if (tomId != null) {
      final basePath = TomCtr.resolvePath(tomId, scope);
      if (basePath != null) {
        final t = TomCtr.textOrNull(basePath, 'actionLabel');
        if (t != null) return t;
      }
    }
    return actionLabel;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headline = _resolvedTitle();
    final body = _resolvedDescription();
    final actionText = _resolvedActionLabel();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: iconSize,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
            if (headline != null) ...[
              const SizedBox(height: 12),
              Text(headline,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center),
            ],
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
                  textAlign: TextAlign.center),
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
