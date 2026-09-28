/// Radio-group container whose authorization is **group-level**: one
/// resource key governs the whole selection, rather than each radio
/// carrying its own. Use it when a grant covers the choice as a unit —
/// a per-field radio is the right tool when the grant varies per option.
///
/// **Not named for the radios it draws.** `TomRadioGroupStyle` and
/// `TomRadioGroupDecorationMixin` belong to the *forms* module and theme the
/// radio-group **field**; they do nothing here, and while this widget shared
/// their name a consumer who found one and set it had no way to know that.
/// This is a composite in the custom kit: it is not a field, takes no part in
/// the form style tree, and — like the rest of `custom/` — takes its
/// appearance from the ambient `ThemeData` rather than from a Tom style
/// object. The name says which of the two it is.
///
/// The widget is value-semantic: callers pass [TomChoiceGroup.items], the
/// current [TomChoiceGroup.selected] value, and the
/// [TomChoiceGroup.onChanged] handler. Internally each tile is rendered
/// with [Radio<T>] + [InkWell] so the group composes cleanly inside
/// Cards / Lists, and the whole column sits under a [RadioGroup] of the
/// same type argument — that ancestor is what carries the selection down
/// to the radios, and it brings arrow-key navigation and the APG
/// radio-group semantics with it.
///
/// Authorization is resolved once via [TomAuthorization.resolveAuth]
/// against [TomChoiceGroup.tomId] (qualified by the active [TomScope]).
/// The four outcomes:
///
/// * `none` — the entire group is hidden.
/// * `disabled` — the group is rendered with [IgnorePointer] + faded
///   opacity; the [TomChoiceGroup.onChanged] callback is never invoked.
/// * `read` — the group is rendered, [TomChoiceGroup.onChanged] is
///   suppressed, but the current [TomChoiceGroup.selected] value is
///   still highlighted.
/// * `full` — the group is fully interactive.
///
/// The two withheld states pass `enabled: false` to every radio as well as
/// wrapping the column in [IgnorePointer]. Both are needed: [IgnorePointer]
/// stops the pointer, and the [RadioGroup] ancestor makes the keyboard a
/// second way in that it would not stop.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../widget_base/tom_scope_path.dart';

/// One radio entry in a [TomChoiceGroup].
class TomChoiceGroupItem<T> {
  /// Underlying value.
  final T value;

  /// Display label.
  final String label;

  /// Optional supporting copy beneath the label.
  final String? description;

  const TomChoiceGroupItem({
    required this.value,
    required this.label,
    this.description,
  });
}

/// Radio group with group-level authorization.
class TomChoiceGroup<T> extends StatelessWidget {
  /// Resource key path used to resolve the group's [TomAuthState].
  /// When `null`, the group renders fully interactive (no auth check).
  final String? tomId;

  /// Optional explicit scope override. When `null`, [TomScope.current]
  /// is used to qualify [tomId].
  final TomScope? scope;

  /// The list of selectable items.
  final List<TomChoiceGroupItem<T>> items;

  /// Currently selected value. Compared by `==`.
  final T? selected;

  /// Handler invoked when the user picks a different item. Suppressed
  /// when group auth is `read` or `disabled`.
  final void Function(T value)? onChanged;

  /// Optional title rendered above the group.
  final String? title;

  /// Opacity applied when group auth is `disabled`. Defaults to `0.4`.
  final double disabledOpacity;

  const TomChoiceGroup({
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
    final fullPath = TomScopePath.resolve(tomId, scope);
    if (fullPath == null) return TomAuthState.full;
    return TomAuthorization.resolveAuth(fullPath);
  }

  @override
  Widget build(BuildContext context) {
    final auth = _resolveAuth();
    if (auth == TomAuthState.none) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isInteractive = auth == TomAuthState.full;

    final column = Column(
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
                  Radio<T>(value: item.value, enabled: isInteractive),
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

    final group = RadioGroup<T>(
      groupValue: selected,
      onChanged: (T? value) {
        if (value != null) onChanged?.call(value);
      },
      child: column,
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
