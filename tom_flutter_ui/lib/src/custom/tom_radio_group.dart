/// Phase 6 — `TomRadioGroup`.
///
/// Radio-group container that applies authorization to the entire
/// selection group. Per-field auth on radio implementations works
/// today, but a stand-alone "grouped radio" layout with **group-level**
/// auth (one resource key controlling the whole group) does not — this
/// widget closes that gap.
///
/// The widget is value-semantic: callers pass [items], the current
/// [selected] value, and an [onChanged] handler. Internally each tile
/// is rendered with [Radio<T>] + [InkWell] so the group composes
/// cleanly inside Cards / Lists.
///
/// Authorization is resolved once via [TomAuthorization.resolveAuth]
/// against [tomId] (qualified by the active [TomScope]). The four
/// outcomes:
///
/// * `none` — the entire group is hidden.
/// * `disabled` — the group is rendered with [IgnorePointer] + faded
///   opacity; the [onChanged] callback is never invoked.
/// * `read` — the group is rendered, [onChanged] is suppressed, but
///   the current [selected] value is still highlighted.
/// * `full` — the group is fully interactive.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// One radio entry in a [TomRadioGroup].
class TomRadioGroupItem<T> {
  /// Underlying value.
  final T value;

  /// Display label.
  final String label;

  /// Optional supporting copy beneath the label.
  final String? description;

  const TomRadioGroupItem({
    required this.value,
    required this.label,
    this.description,
  });
}

/// Radio group with group-level authorization.
class TomRadioGroup<T> extends StatelessWidget {
  /// Resource key path used to resolve the group's [TomAuthState].
  /// When `null`, the group renders fully interactive (no auth check).
  final String? tomId;

  /// Optional explicit scope override. When `null`, [TomScope.current]
  /// is used to qualify [tomId].
  final TomScope? scope;

  /// The list of selectable items.
  final List<TomRadioGroupItem<T>> items;

  /// Currently selected value. Compared by `==`.
  final T? selected;

  /// Handler invoked when the user picks a different item. Suppressed
  /// when group auth is `read` or `disabled`.
  final void Function(T value)? onChanged;

  /// Optional title rendered above the group.
  final String? title;

  /// Opacity applied when group auth is `disabled`. Defaults to `0.4`.
  final double disabledOpacity;

  const TomRadioGroup({
    super.key,
    this.tomId,
    this.scope,
    required this.items,
    this.selected,
    this.onChanged,
    this.title,
    this.disabledOpacity = 0.4,
  });

  TomAuthState _resolveAuth() {
    if (tomId == null) return TomAuthState.full;
    final effectiveScope = scope ?? TomScope.current;
    final scopePath = effectiveScope.getScopePath();
    final fullPath = scopePath.isEmpty ? tomId! : '$scopePath.$tomId';
    return TomAuthorization.resolveAuth(fullPath);
  }

  @override
  Widget build(BuildContext context) {
    final auth = _resolveAuth();
    if (auth == TomAuthState.none) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isInteractive = auth == TomAuthState.full;

    final group = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(title!, style: theme.textTheme.titleSmall),
          ),
        ],
        for (final item in items)
          InkWell(
            onTap: isInteractive ? () => onChanged?.call(item.value) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Radio<T>(
                    value: item.value,
                    groupValue: selected,
                    onChanged: isInteractive
                        ? (T? value) {
                            if (value != null) onChanged?.call(value);
                          }
                        : null,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.label, style: theme.textTheme.bodyMedium),
                        if (item.description != null)
                          Text(
                            item.description!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    if (auth == TomAuthState.disabled) {
      return IgnorePointer(
        child: Opacity(opacity: disabledOpacity, child: group),
      );
    }
    if (auth == TomAuthState.read) {
      return IgnorePointer(child: group);
    }
    return group;
  }
}
