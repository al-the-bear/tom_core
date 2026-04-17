import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Realtime table of every field in the provided forms.
///
/// Columns: Field ID · Value · Auth · Validation · Dirty.
/// Rows are colour-coded by validation state — green (success), red (error),
/// yellow (pending), grey (disabled auth), white (pristine).
///
/// The table rebuilds on every form event via `form.changes`, so value,
/// auth, validation, and dirty transitions all update without `setState`.
class FieldStateTable extends StatelessWidget {
  /// Forms whose fields to display. Multiple forms render as separate
  /// sections so Demo C (nested form tree) can show `customer`, `billing`,
  /// and `shipping` side-by-side.
  final List<TomForm> forms;

  const FieldStateTable({super.key, required this.forms});

  @override
  Widget build(BuildContext context) {
    final listenable = Listenable.merge([for (final f in forms) f.changes]);
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) => _buildTable(context),
    );
  }

  Widget _buildTable(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final form in forms) _buildFormSection(context, form),
      ],
    );
  }

  Widget _buildFormSection(BuildContext context, TomForm form) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              form.formId,
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(3),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(2),
              4: FlexColumnWidth(1),
            },
            border: TableBorder.all(
              color: theme.dividerColor,
              width: 0.5,
            ),
            children: [
              _headerRow(theme),
              for (final field in form.fields.values) _row(theme, field),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _headerRow(ThemeData theme) {
    final style = theme.textTheme.labelSmall
        ?.copyWith(fontWeight: FontWeight.w600);
    return TableRow(
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHigh),
      children: [
        _cell('Field', style),
        _cell('Value', style),
        _cell('Auth', style),
        _cell('Validation', style),
        _cell('Dirty', style),
      ],
    );
  }

  TableRow _row(ThemeData theme, TomField field) {
    final auth = field.effectiveAuthState;
    final validation = field.validationState;
    final color = _rowColour(theme, auth, validation);
    final textStyle = theme.textTheme.bodySmall;
    final value = field.get();
    final displayValue = field.obscureText
        ? (value is String && value.isNotEmpty ? '••••••' : '')
        : _short(value.toString());
    return TableRow(
      decoration: BoxDecoration(color: color),
      children: [
        _cell(field.fieldId, textStyle),
        _cell(displayValue, textStyle),
        _cell(_authLabel(auth), textStyle),
        _cell(_validationLabel(validation), textStyle),
        _cell(
          field.isDirty ? '●' : '',
          textStyle?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  static String _short(String s) =>
      s.length > 24 ? '${s.substring(0, 24)}…' : s;

  static Widget _cell(String text, TextStyle? style) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          text,
          style: style,
          overflow: TextOverflow.ellipsis,
        ),
      );

  static String _authLabel(TomAuthState s) => switch (s) {
        TomAuthState.full => 'full',
        TomAuthState.read => 'read',
        TomAuthState.disabled => 'disabled',
        TomAuthState.none => 'none',
      };

  static String _validationLabel(ValidationResult r) => switch (r) {
        ValidationPristine() => 'pristine',
        ValidationSuccess() => 'valid',
        ValidationPending() => 'pending',
        ValidationError(:final errorKey) => 'error: $errorKey',
      };

  static Color _rowColour(
    ThemeData theme,
    TomAuthState auth,
    ValidationResult v,
  ) {
    if (auth == TomAuthState.disabled) return theme.colorScheme.surfaceContainer;
    if (auth == TomAuthState.none) return theme.colorScheme.surfaceContainerLow;
    return switch (v) {
      ValidationError() => theme.colorScheme.errorContainer.withValues(alpha: 0.4),
      ValidationPending() => Colors.amber.withValues(alpha: 0.25),
      ValidationSuccess() => Colors.green.withValues(alpha: 0.12),
      ValidationPristine() => theme.colorScheme.surface,
    };
  }
}
