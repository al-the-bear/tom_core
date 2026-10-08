import 'package:flutter/material.dart';

import '../decoration/tom_field_anatomy.dart';
import '../events/tom_form_event.dart';
import '../events/tom_form_event_listener.dart';
import '../events/tom_form_event_source.dart';
import '../style/tom_form_style.dart';
import '../style/tom_form_style_scope.dart';
import '../tom_form_labels.dart';
import '../validation/form_validation_error.dart';

/// Material-style banner that displays form-level (cross-field) errors.
///
/// Field-level errors are displayed by each field's own decoration.
/// This banner shows only the errors from [TomForm.validate()] that
/// are cross-field validation failures, each worded by
/// [resolveFormValidationMessage].
///
/// Subscribes to the form's event system to show/hide automatically.
/// Auto-dismisses when the form becomes valid; not user-dismissible.
class TomFormErrorBanner extends StatefulWidget {
  /// The form whose cross-field errors are displayed.
  final TomFormEventSource form;

  const TomFormErrorBanner({super.key, required this.form});

  @override
  State<TomFormErrorBanner> createState() => _TomFormErrorBannerState();
}

class _TomFormErrorBannerState extends State<TomFormErrorBanner>
    with TomFormEventListener {
  List<TomFormValidationError> _errors = [];

  @override
  void initState() {
    super.initState();
    widget.form.addListener(this);
  }

  @override
  void didUpdateWidget(TomFormErrorBanner oldWidget) {
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
  void onFormValidated(TomFormValidatedEvent event) {
    setState(() {
      // Show only cross-field errors (errors spanning multiple fields)
      _errors = event.errors
          .whereType<TomFormValidationError>()
          .where((e) => e.fields.length != 1)
          .toList();
    });
  }

  @override
  void onFormSaved(TomFormSavedEvent event) {
    setState(() => _errors = []);
  }

  @override
  void onFormDiscarded(TomFormDiscardedEvent event) {
    setState(() => _errors = []);
  }

  /// Update errors externally (e.g., after calling form.validate()).
  void setErrors(List<TomFormValidationError> errors) {
    setState(() {
      _errors = errors.where((e) => e.fields.length != 1).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_errors.isEmpty) return const SizedBox.shrink();

    final form = TomFormStyleScope.of(context);
    final theme = Theme.of(context);

    return _buildBanner(form.defaults, theme);
  }

  Widget _buildBanner(TomFieldStyle style, ThemeData theme) {
    final errorColor = theme.colorScheme.error;
    final errorContainer = theme.colorScheme.errorContainer;
    final onErrorContainer = theme.colorScheme.onErrorContainer;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: style.errorFieldGap * 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: errorContainer,
        borderRadius: BorderRadius.circular(style.borderRadius),
        border: Border.all(color: errorColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: errorColor, size: 20),
              const SizedBox(width: 8),
              Text(
                // Resolved globally: the banner reports the whole form, so
                // there is no one field whose scope should reword it.
                TomFormLabels.errorBannerTitle(null),
                style: (style.errorStyle ?? theme.textTheme.titleSmall)
                    ?.copyWith(color: onErrorContainer),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._errors.map(
            (error) => Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 4),
              child: Text(
                resolveFormValidationMessage(error),
                style: (style.errorStyle ?? theme.textTheme.bodySmall)
                    ?.copyWith(color: onErrorContainer),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
