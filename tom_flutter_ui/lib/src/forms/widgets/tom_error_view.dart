import 'package:flutter/material.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../events/tom_form_event.dart';
import '../events/tom_form_event_listener.dart';
import '../events/tom_form_event_source.dart';
import '../style/tom_form_style_scope.dart';
import '../validation/form_validation_error.dart';

/// Placement-flexible form-wide error display.
///
/// Renders the current set of validation errors for [form] wherever it
/// is mounted — above, below, or beside the form (unlike
/// `TomFormErrorBanner`, which is locked to a banner slot at the top).
///
/// Subscribes to the form's event bus and rebuilds on
/// [FormValidatedEvent] / [FormSavedEvent] / [FormDiscardedEvent].
///
/// Errors are resolved through `TomCtr.text(...)` so callers can use
/// resource keys like `'order.items.minRequired'` and have them
/// resolved by the active text resource provider. Unresolved keys fall
/// back to the raw key.
class TomErrorView extends StatefulWidget {
  const TomErrorView({
    super.key,
    required this.form,
    this.title,
    this.emptyState,
    this.onErrorTap,
    this.includeFieldErrors = true,
    this.padding = const EdgeInsets.all(12),
  });

  /// Source of form events to observe (typically a [TomForm]).
  final TomFormEventSource form;

  /// Optional title shown above the list. When null, no header is drawn.
  final String? title;

  /// Optional widget shown when there are no errors. When null and the
  /// list is empty, the view collapses to [SizedBox.shrink].
  final Widget? emptyState;

  /// Optional handler invoked when an error row is tapped — useful for
  /// "focus this field" affordances. Receives the original
  /// [FormValidationError].
  final void Function(FormValidationError error)? onErrorTap;

  /// Whether per-field validation errors are included alongside cross-
  /// field ones. Defaults to `true`. When set to `false`, behaves like
  /// [TomFormErrorBanner] (cross-field errors only).
  final bool includeFieldErrors;

  final EdgeInsetsGeometry padding;

  @override
  State<TomErrorView> createState() => _TomErrorViewState();
}

class _TomErrorViewState extends State<TomErrorView>
    with TomFormEventListener {
  List<FormValidationError> _errors = [];

  @override
  void initState() {
    super.initState();
    widget.form.addListener(this);
  }

  @override
  void didUpdateWidget(covariant TomErrorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.form != widget.form) {
      oldWidget.form.removeListener(this);
      widget.form.addListener(this);
      _errors = [];
    }
  }

  @override
  void dispose() {
    widget.form.removeListener(this);
    super.dispose();
  }

  @override
  void onFormValidated(FormValidatedEvent event) {
    setState(() {
      final errors = event.errors.whereType<FormValidationError>();
      _errors = widget.includeFieldErrors
          ? errors.toList()
          : errors.where((e) => e.fields.length != 1).toList();
    });
  }

  @override
  void onFormSaved(FormSavedEvent event) {
    setState(() => _errors = []);
  }

  @override
  void onFormDiscarded(FormDiscardedEvent event) {
    setState(() => _errors = []);
  }

  /// Imperative override — primarily for tests / demos that compute the
  /// error list separately from form events.
  void setErrors(List<FormValidationError> errors) {
    setState(() {
      _errors = widget.includeFieldErrors
          ? errors
          : errors.where((e) => e.fields.length != 1).toList();
    });
  }

  /// Resolve a [FormValidationError] to user-facing text.
  ///
  /// Round-6 (d) bug fix:
  ///   - Previously prefixed `'error.'` to `error.errorKey` when looking
  ///     up the field-scoped variant, but `errorKey` already includes the
  ///     `error.` prefix produced by stock validators (e.g.
  ///     `error.required`). The double-prefix lookup never matched.
  ///   - Previously the global lookup used `TomCtr.textOrNull('', key)`,
  ///     which builds the resource path as `'.<key>'` (leading dot) and
  ///     breaks `getObjectFromTree`. We now pass the key as `basePath`
  ///     directly with an empty suffix, matching the same pattern used by
  ///     `resolveFieldValidationMessage`.
  String _resolveMessage(FormValidationError error) {
    final key = error.errorKey;
    if (error.fields.length == 1) {
      final field = error.fields.first;
      final scoped = TomCtr.textOrNull(field.basePath, key);
      if (scoped != null) return _applyParams(scoped, error.params);
    }
    final global = TomCtr.textOrNull(key);
    if (global != null) return _applyParams(global, error.params);
    return key;
  }

  String _applyParams(String template, Map<String, dynamic>? params) {
    if (params == null || params.isEmpty) return template;
    var out = template;
    params.forEach((k, v) => out = out.replaceAll('{$k}', '$v'));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = TomFormStyleScope.of(context);

    if (_errors.isEmpty) {
      return widget.emptyState ?? const SizedBox.shrink();
    }

    final errorColor = theme.colorScheme.error;
    final errorContainer = theme.colorScheme.errorContainer;
    final onErrorContainer = theme.colorScheme.onErrorContainer;

    return Container(
      width: double.infinity,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: errorContainer,
        borderRadius: BorderRadius.circular(style.defaults.borderRadius),
        border: Border.all(color: errorColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.title != null) ...[
            Row(children: [
              Icon(Icons.error_outline, color: errorColor, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.title!,
                style: (style.defaults.errorStyle ??
                        theme.textTheme.titleSmall)
                    ?.copyWith(color: onErrorContainer),
              ),
            ]),
            const SizedBox(height: 8),
          ],
          ..._errors.map((error) {
            final message = _resolveMessage(error);
            final row = Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.warning_amber_rounded,
                        color: errorColor, size: 16),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      message,
                      style: (style.defaults.errorStyle ??
                              theme.textTheme.bodySmall)
                          ?.copyWith(color: onErrorContainer),
                    ),
                  ),
                ],
              ),
            );
            if (widget.onErrorTap == null) return row;
            return InkWell(
              onTap: () => widget.onErrorTap!(error),
              child: row,
            );
          }),
        ],
      ),
    );
  }
}
