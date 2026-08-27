/// Cupertino Date / Time / Duration / Range concretes.
///
/// Five concretes that subclass the same abstract date/time
/// fields used by the Material side, but render their inner picker as
/// a `CupertinoDatePicker` / `CupertinoTimerPicker` inside a
/// `showCupertinoModalPopup` sheet:
///   * [TomCupertinoFormDatePicker]      → `CupertinoDatePicker(date)`
///   * [TomCupertinoFormTimePicker]      → `CupertinoDatePicker(time)`
///   * [TomCupertinoFormDateTimePicker]  → `CupertinoDatePicker(dateAndTime)`
///   * [TomCupertinoFormDurationPicker]  → `CupertinoTimerPicker`
///   * [TomCupertinoFormDateRangePicker] → two stacked date pickers
///
/// Surface: every concrete uses [TomGenericFieldDecorationMixin] so
/// label / error / description / action icons render through the same
/// anatomy as the Material counterparts. The on-tap tile renders via
/// [cupertinoFieldDecoration] for visual parity with the string-picker tiles.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DateTimeRange, TimeOfDay, Theme;
import '../../tom_form_labels.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../../widget_base/tom_construction_helpers.dart';
import '../../decoration/tom_generic_field_decoration_mixin.dart';
import '../../style/tom_cupertino_form_style.dart';
import '../../style/tom_form_style.dart';
import '../../style/tom_form_style_scope.dart';
import '../tom_field_widget_adapter.dart';
import '../tom_form_date_time_fields.dart';
import '../tom_form_duration_field.dart';

// ===========================================================================
// Shared helpers
// ===========================================================================

/// Renders a Cupertino-style trigger tile that displays [label] and a
/// trailing chevron. Tapping invokes [onTap]. Uses the same surface
/// decoration as the Cupertino string-picker tiles so date/time/range
/// fields sit visually flush with string pickers.
Widget _cupertinoTriggerTile({
  required BuildContext context,
  required TomFieldStyle style,
  required IconData icon,
  required String label,
  required bool enabled,
  required VoidCallback? onTap,
}) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: enabled ? onTap : null,
    child: Container(
      padding: style.fieldContentPadding,
      decoration: cupertinoFieldDecoration(
        context: context,
        borderRadius: style.borderRadius,
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 18, color: CupertinoColors.secondaryLabel),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: style.inputStyle),
          ),
          const Icon(
            CupertinoIcons.chevron_down,
            size: 18,
            color: CupertinoColors.secondaryLabel,
          ),
        ],
      ),
    ),
  );
}

/// Wraps [picker] in a modal-popup sheet with Cancel/Done buttons.
/// Calls [onDone] only when the user taps Done; Cancel just closes.
///
/// [basePath] is the opening field's resource scope, so one field can reword
/// the two buttons without the application rewording every sheet.
Future<void> _showCupertinoPickerSheet({
  required BuildContext context,
  required Widget picker,
  required VoidCallback onDone,
  String? basePath,
  double sheetHeight = 216,
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => Container(
      height: sheetHeight + 56,
      color: CupertinoColors.systemBackground.resolveFrom(ctx),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(TomFormLabels.cancel(basePath)),
                ),
                CupertinoButton(
                  onPressed: () {
                    onDone();
                    Navigator.of(ctx).pop();
                  },
                  child: Text(TomFormLabels.done(basePath)),
                ),
              ],
            ),
            Expanded(child: picker),
          ],
        ),
      ),
    ),
  );
}

// ===========================================================================
// TomCupertinoFormDatePicker — CupertinoDatePicker (date mode)
// ===========================================================================

@tomReflector
class TomCupertinoFormDatePicker extends TomFormDateField
    with TomGenericFieldDecorationMixin<DateTime> {
  TomCupertinoFormDatePicker(
    super.tomId,
    super.initialValue, {
    required super.firstDate,
    required super.lastDate,
    super.labelTextOverride,
    super.descriptionTextOverride,
    super.form,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
    super.actionIcon,
    super.actionIconTooltip,
    super.onActionIconPressed,
  });

  // The mixin's `labelText` / `descriptionText` getters return null by
  // default; concrete classes have to delegate to the abstract field's
  // resolution chain so the field anatomy renders the label above the
  // picker tile.
  @override
  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');

  @override
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  @override
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.datePickerStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _CupertinoDatePickerWidget(field: this),
      );
}

class _CupertinoDatePickerWidget extends StatefulWidget {
  final TomCupertinoFormDatePicker field;
  const _CupertinoDatePickerWidget({required this.field});

  @override
  State<_CupertinoDatePickerWidget> createState() =>
      _CupertinoDatePickerWidgetState();
}

class _CupertinoDatePickerWidgetState
    extends State<_CupertinoDatePickerWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomCupertinoFormDatePicker get field => widget.field;

  @override
  void initState() {
    super.initState();
    _observer = field >> (_) {
      if (mounted) setState(() {});
    };
    field.validationListenable.addListener(_onValidationChanged);
  }

  void _onValidationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    field.validationListenable.removeListener(_onValidationChanged);
    field.removeObserver(_observer);
    super.dispose();
  }

  void _open() {
    DateTime temp = field.get();
    _showCupertinoPickerSheet(
      context: context,
      basePath: field.basePath,
      picker: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        initialDateTime: field.get(),
        minimumDate: field.firstDate,
        maximumDate: field.lastDate,
        onDateTimeChanged: (d) => temp = d,
      ),
      onDone: () =>
          field.setValue(DateTime(temp.year, temp.month, temp.day)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final tile = _cupertinoTriggerTile(
      context: context,
      style: style,
      icon: CupertinoIcons.calendar,
      label: field.formatDate(field.get()),
      enabled: field.isEditable,
      onTap: _open,
    );
    return field.decorateField(context, tile);
  }
}

// ===========================================================================
// TomCupertinoFormTimePicker — CupertinoDatePicker (time mode)
// ===========================================================================

@tomReflector
class TomCupertinoFormTimePicker extends TomFormTimeField
    with TomGenericFieldDecorationMixin<TimeOfDay> {
  TomCupertinoFormTimePicker(
    super.tomId,
    super.initialValue, {
    super.labelTextOverride,
    super.descriptionTextOverride,
    super.form,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
    super.actionIcon,
    super.actionIconTooltip,
    super.onActionIconPressed,
  });

  @override
  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');

  @override
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  @override
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.timePickerStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _CupertinoTimePickerWidget(field: this),
      );
}

class _CupertinoTimePickerWidget extends StatefulWidget {
  final TomCupertinoFormTimePicker field;
  const _CupertinoTimePickerWidget({required this.field});

  @override
  State<_CupertinoTimePickerWidget> createState() =>
      _CupertinoTimePickerWidgetState();
}

class _CupertinoTimePickerWidgetState
    extends State<_CupertinoTimePickerWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomCupertinoFormTimePicker get field => widget.field;

  @override
  void initState() {
    super.initState();
    _observer = field >> (_) {
      if (mounted) setState(() {});
    };
    field.validationListenable.addListener(_onValidationChanged);
  }

  void _onValidationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    field.validationListenable.removeListener(_onValidationChanged);
    field.removeObserver(_observer);
    super.dispose();
  }

  void _open() {
    final t = field.get();
    DateTime temp =
        DateTime(2020, 1, 1, t.hour, t.minute);
    _showCupertinoPickerSheet(
      context: context,
      basePath: field.basePath,
      picker: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        initialDateTime: temp,
        onDateTimeChanged: (d) => temp = d,
      ),
      onDone: () =>
          field.setValue(TimeOfDay(hour: temp.hour, minute: temp.minute)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final tile = _cupertinoTriggerTile(
      context: context,
      style: style,
      icon: CupertinoIcons.time,
      label: field.formatTime(field.get()),
      enabled: field.isEditable,
      onTap: _open,
    );
    return field.decorateField(context, tile);
  }
}

// ===========================================================================
// TomCupertinoFormDateTimePicker — CupertinoDatePicker (dateAndTime mode)
// ===========================================================================

@tomReflector
class TomCupertinoFormDateTimePicker extends TomFormDateTimeField
    with TomGenericFieldDecorationMixin<DateTime> {
  TomCupertinoFormDateTimePicker(
    super.tomId,
    super.initialValue, {
    required super.firstDate,
    required super.lastDate,
    super.labelTextOverride,
    super.descriptionTextOverride,
    super.form,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
    super.actionIcon,
    super.actionIconTooltip,
    super.onActionIconPressed,
  });

  @override
  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');

  @override
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  @override
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.datePickerStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _CupertinoDateTimePickerWidget(field: this),
      );
}

class _CupertinoDateTimePickerWidget extends StatefulWidget {
  final TomCupertinoFormDateTimePicker field;
  const _CupertinoDateTimePickerWidget({required this.field});

  @override
  State<_CupertinoDateTimePickerWidget> createState() =>
      _CupertinoDateTimePickerWidgetState();
}

class _CupertinoDateTimePickerWidgetState
    extends State<_CupertinoDateTimePickerWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomCupertinoFormDateTimePicker get field => widget.field;

  @override
  void initState() {
    super.initState();
    _observer = field >> (_) {
      if (mounted) setState(() {});
    };
    field.validationListenable.addListener(_onValidationChanged);
  }

  void _onValidationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    field.validationListenable.removeListener(_onValidationChanged);
    field.removeObserver(_observer);
    super.dispose();
  }

  void _open() {
    DateTime temp = field.get();
    _showCupertinoPickerSheet(
      context: context,
      basePath: field.basePath,
      picker: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.dateAndTime,
        initialDateTime: field.get(),
        minimumDate: field.firstDate,
        maximumDate: field.lastDate,
        onDateTimeChanged: (d) => temp = d,
      ),
      onDone: () => field.setValue(temp),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final tile = _cupertinoTriggerTile(
      context: context,
      style: style,
      icon: CupertinoIcons.calendar_today,
      label: field.formatDateTime(field.get()),
      enabled: field.isEditable,
      onTap: _open,
    );
    return field.decorateField(context, tile);
  }
}

// ===========================================================================
// TomCupertinoFormDurationPicker — CupertinoTimerPicker
// ===========================================================================

@tomReflector
class TomCupertinoFormDurationPicker extends TomFormDurationField
    with TomGenericFieldDecorationMixin<Duration> {
  /// Picker mode (defaults to hour + minute).
  final CupertinoTimerPickerMode mode;

  /// Minute interval for the picker (must divide 60 evenly).
  final int minuteInterval;

  TomCupertinoFormDurationPicker(
    super.tomId,
    super.initialValue, {
    this.mode = CupertinoTimerPickerMode.hm,
    this.minuteInterval = 1,
    super.labelTextOverride,
    super.descriptionTextOverride,
    super.form,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
    super.actionIcon,
    super.actionIconTooltip,
    super.onActionIconPressed,
  });

  @override
  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');

  @override
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  @override
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.stringInputStyle, width);
  }

  String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes - h * 60;
    final s = d.inSeconds - d.inMinutes * 60;
    if (mode == CupertinoTimerPickerMode.ms) {
      return '${m.toString().padLeft(2, '0')}m '
          '${s.toString().padLeft(2, '0')}s';
    }
    if (mode == CupertinoTimerPickerMode.hms) {
      return '${h.toString().padLeft(2, '0')}h '
          '${m.toString().padLeft(2, '0')}m '
          '${s.toString().padLeft(2, '0')}s';
    }
    return '${h.toString().padLeft(2, '0')}h '
        '${m.toString().padLeft(2, '0')}m';
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _CupertinoDurationPickerWidget(field: this),
      );
}

class _CupertinoDurationPickerWidget extends StatefulWidget {
  final TomCupertinoFormDurationPicker field;
  const _CupertinoDurationPickerWidget({required this.field});

  @override
  State<_CupertinoDurationPickerWidget> createState() =>
      _CupertinoDurationPickerWidgetState();
}

class _CupertinoDurationPickerWidgetState
    extends State<_CupertinoDurationPickerWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomCupertinoFormDurationPicker get field => widget.field;

  @override
  void initState() {
    super.initState();
    _observer = field >> (_) {
      if (mounted) setState(() {});
    };
    field.validationListenable.addListener(_onValidationChanged);
  }

  void _onValidationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    field.validationListenable.removeListener(_onValidationChanged);
    field.removeObserver(_observer);
    super.dispose();
  }

  void _open() {
    Duration temp = field.get();
    _showCupertinoPickerSheet(
      context: context,
      basePath: field.basePath,
      picker: CupertinoTimerPicker(
        mode: field.mode,
        initialTimerDuration: field.get(),
        minuteInterval: field.minuteInterval,
        onTimerDurationChanged: (d) => temp = d,
      ),
      onDone: () => field.setValue(temp),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final tile = _cupertinoTriggerTile(
      context: context,
      style: style,
      icon: CupertinoIcons.timer,
      label: field.formatDuration(field.get()),
      enabled: field.isEditable,
      onTap: _open,
    );
    return field.decorateField(context, tile);
  }
}

// ===========================================================================
// TomCupertinoFormDateRangePicker — two CupertinoDatePickers in one sheet
// ===========================================================================

@tomReflector
class TomCupertinoFormDateRangePicker extends TomFormDateRangeField
    with TomGenericFieldDecorationMixin<DateTimeRange> {
  TomCupertinoFormDateRangePicker(
    super.tomId,
    super.initialValue, {
    required super.firstDate,
    required super.lastDate,
    super.labelTextOverride,
    super.descriptionTextOverride,
    super.form,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
    super.actionIcon,
    super.actionIconTooltip,
    super.onActionIconPressed,
  });

  @override
  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');

  @override
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  @override
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.datePickerStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _CupertinoDateRangePickerWidget(field: this),
      );
}

class _CupertinoDateRangePickerWidget extends StatefulWidget {
  final TomCupertinoFormDateRangePicker field;
  const _CupertinoDateRangePickerWidget({required this.field});

  @override
  State<_CupertinoDateRangePickerWidget> createState() =>
      _CupertinoDateRangePickerWidgetState();
}

class _CupertinoDateRangePickerWidgetState
    extends State<_CupertinoDateRangePickerWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomCupertinoFormDateRangePicker get field => widget.field;

  @override
  void initState() {
    super.initState();
    _observer = field >> (_) {
      if (mounted) setState(() {});
    };
    field.validationListenable.addListener(_onValidationChanged);
  }

  void _onValidationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    field.validationListenable.removeListener(_onValidationChanged);
    field.removeObserver(_observer);
    super.dispose();
  }

  void _open() {
    final current = field.get();
    DateTime tempStart = current.start;
    DateTime tempEnd = current.end;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return Container(
          height: 360,
          color: CupertinoColors.systemBackground.resolveFrom(ctx),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(TomFormLabels.cancel(field.basePath)),
                    ),
                    CupertinoButton(
                      onPressed: () {
                        // Normalize order so start <= end.
                        final s = tempStart.isAfter(tempEnd)
                            ? tempEnd
                            : tempStart;
                        final e = tempStart.isAfter(tempEnd)
                            ? tempStart
                            : tempEnd;
                        field.setValue(DateTimeRange(start: s, end: e));
                        Navigator.of(ctx).pop();
                      },
                      child: Text(TomFormLabels.done(field.basePath)),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    TomFormLabels.rangeStart(field.basePath),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                SizedBox(
                  height: 120,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: current.start,
                    minimumDate: field.firstDate,
                    maximumDate: field.lastDate,
                    onDateTimeChanged: (d) => tempStart =
                        DateTime(d.year, d.month, d.day),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    TomFormLabels.rangeEnd(field.basePath),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                SizedBox(
                  height: 120,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: current.end,
                    minimumDate: field.firstDate,
                    maximumDate: field.lastDate,
                    onDateTimeChanged: (d) =>
                        tempEnd = DateTime(d.year, d.month, d.day),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final tile = _cupertinoTriggerTile(
      context: context,
      style: style,
      icon: CupertinoIcons.calendar_badge_plus,
      label: field.formatRange(field.get()),
      enabled: field.isEditable,
      onTap: _open,
    );
    return field.decorateField(context, tile);
  }
}
