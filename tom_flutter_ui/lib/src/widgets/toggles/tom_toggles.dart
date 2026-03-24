import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../widget_base/tom_family_base.dart';

/// Tom wrapper for [Switch].
///
/// Adds ID, group, authorization, and resource resolution for label.
class TomSwitch extends TomToggleBase {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final Color? activeTrackColor;
  final Color? inactiveThumbColor;
  final Color? inactiveTrackColor;
  final ImageProvider? activeThumbImage;
  final ImageProvider? inactiveThumbImage;
  final WidgetStateProperty<Color?>? thumbColor;
  final WidgetStateProperty<Color?>? trackColor;
  final WidgetStateProperty<Color?>? trackOutlineColor;
  final WidgetStateProperty<double?>? trackOutlineWidth;
  final WidgetStateProperty<Icon?>? thumbIcon;
  final DragStartBehavior? dragStartBehavior;
  final FocusNode? focusNode;
  final bool autofocus;
  final WidgetStateProperty<Color?>? overlayColor;
  final double? splashRadius;

  const TomSwitch({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.value,
    this.onChanged,
    this.activeColor,
    this.activeTrackColor,
    this.inactiveThumbColor,
    this.inactiveTrackColor,
    this.activeThumbImage,
    this.inactiveThumbImage,
    this.thumbColor,
    this.trackColor,
    this.trackOutlineColor,
    this.trackOutlineWidth,
    this.thumbIcon,
    this.dragStartBehavior,
    this.focusNode,
    this.autofocus = false,
    this.overlayColor,
    this.splashRadius,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: activeColor,
      activeTrackColor: activeTrackColor,
      inactiveThumbColor: inactiveThumbColor,
      inactiveTrackColor: inactiveTrackColor,
      activeThumbImage: activeThumbImage,
      inactiveThumbImage: inactiveThumbImage,
      thumbColor: thumbColor,
      trackColor: trackColor,
      trackOutlineColor: trackOutlineColor,
      trackOutlineWidth: trackOutlineWidth,
      thumbIcon: thumbIcon,
      focusNode: focusNode,
      autofocus: autofocus,
      overlayColor: overlayColor,
      splashRadius: splashRadius,
    );
  }
}

/// Tom wrapper for [Checkbox].
///
/// Adds ID, group, authorization, and resource resolution for label.
class TomCheckbox extends TomToggleBase {
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final bool tristate;
  final Color? activeColor;
  final WidgetStateProperty<Color?>? fillColor;
  final Color? checkColor;
  final Color? focusColor;
  final Color? hoverColor;
  final WidgetStateProperty<Color?>? overlayColor;
  final double? splashRadius;
  final VisualDensity? visualDensity;
  final OutlinedBorder? shape;
  final BorderSide? side;
  final bool isError;
  final FocusNode? focusNode;
  final bool autofocus;

  const TomCheckbox({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.value,
    this.onChanged,
    this.tristate = false,
    this.activeColor,
    this.fillColor,
    this.checkColor,
    this.focusColor,
    this.hoverColor,
    this.overlayColor,
    this.splashRadius,
    this.visualDensity,
    this.shape,
    this.side,
    this.isError = false,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Checkbox(
      value: value,
      onChanged: onChanged,
      tristate: tristate,
      activeColor: activeColor,
      fillColor: fillColor,
      checkColor: checkColor,
      focusColor: focusColor,
      hoverColor: hoverColor,
      overlayColor: overlayColor,
      splashRadius: splashRadius,
      visualDensity: visualDensity,
      shape: shape,
      side: side,
      isError: isError,
      focusNode: focusNode,
      autofocus: autofocus,
    );
  }
}

/// Tom wrapper for [Radio].
///
/// Adds ID, group, authorization, and resource resolution for label.
class TomRadio<T> extends TomToggleBase {
  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final Color? activeColor;
  final WidgetStateProperty<Color?>? fillColor;
  final Color? focusColor;
  final Color? hoverColor;
  final WidgetStateProperty<Color?>? overlayColor;
  final double? splashRadius;
  final VisualDensity? visualDensity;
  final bool toggleable;
  final FocusNode? focusNode;
  final bool autofocus;

  const TomRadio({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.value,
    this.groupValue,
    this.onChanged,
    this.activeColor,
    this.fillColor,
    this.focusColor,
    this.hoverColor,
    this.overlayColor,
    this.splashRadius,
    this.visualDensity,
    this.toggleable = false,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Radio<T>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: activeColor,
      fillColor: fillColor,
      focusColor: focusColor,
      hoverColor: hoverColor,
      overlayColor: overlayColor,
      splashRadius: splashRadius,
      visualDensity: visualDensity,
      toggleable: toggleable,
      focusNode: focusNode,
      autofocus: autofocus,
    );
  }
}

/// Tom wrapper for [SwitchListTile].
///
/// Adds ID, group, authorization, and resource resolution for title.
class TomSwitchListTile extends TomToggleBase {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? title;
  final String? titleText;
  final Widget? subtitle;
  final Widget? secondary;
  final bool isThreeLine;
  final bool? dense;
  final EdgeInsetsGeometry? contentPadding;
  final Color? activeColor;
  final Color? activeTrackColor;
  final Color? inactiveThumbColor;
  final Color? inactiveTrackColor;
  final bool autofocus;
  final FocusNode? focusNode;
  final ListTileControlAffinity controlAffinity;
  final ShapeBorder? shape;
  final Color? tileColor;
  final Color? selectedTileColor;
  final VisualDensity? visualDensity;
  final bool? enableFeedback;
  final Color? hoverColor;

  const TomSwitchListTile({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.value,
    this.onChanged,
    this.title,
    this.titleText,
    this.subtitle,
    this.secondary,
    this.isThreeLine = false,
    this.dense,
    this.contentPadding,
    this.activeColor,
    this.activeTrackColor,
    this.inactiveThumbColor,
    this.inactiveTrackColor,
    this.autofocus = false,
    this.focusNode,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.shape,
    this.tileColor,
    this.selectedTileColor,
    this.visualDensity,
    this.enableFeedback,
    this.hoverColor,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedTitle =
        titleText ?? (tomId != null ? resolveResource(context, 'label') : null);
    final effectiveTitle = title ??
        (resolvedTitle != null
            ? Text(resolvedTitle)
            : const SizedBox.shrink());

    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: effectiveTitle,
      subtitle: subtitle,
      secondary: secondary,
      isThreeLine: isThreeLine,
      dense: dense,
      contentPadding: contentPadding,
      activeColor: activeColor,
      activeTrackColor: activeTrackColor,
      inactiveThumbColor: inactiveThumbColor,
      inactiveTrackColor: inactiveTrackColor,
      autofocus: autofocus,
      focusNode: focusNode,
      controlAffinity: controlAffinity,
      shape: shape,
      tileColor: tileColor,
      selectedTileColor: selectedTileColor,
      visualDensity: visualDensity,
      enableFeedback: enableFeedback,
      hoverColor: hoverColor,
    );
  }
}

/// Tom wrapper for [CheckboxListTile].
///
/// Adds ID, group, authorization, and resource resolution for title.
class TomCheckboxListTile extends TomToggleBase {
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final Widget? title;
  final String? titleText;
  final Widget? subtitle;
  final Widget? secondary;
  final bool isThreeLine;
  final bool? dense;
  final EdgeInsetsGeometry? contentPadding;
  final Color? activeColor;
  final Color? checkColor;
  final bool tristate;
  final ShapeBorder? shape;
  final BorderSide? side;
  final Color? tileColor;
  final Color? selectedTileColor;
  final VisualDensity? visualDensity;
  final bool? enableFeedback;
  final ListTileControlAffinity controlAffinity;
  final bool autofocus;
  final FocusNode? focusNode;
  final OutlinedBorder? checkboxShape;

  const TomCheckboxListTile({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.value,
    this.onChanged,
    this.title,
    this.titleText,
    this.subtitle,
    this.secondary,
    this.isThreeLine = false,
    this.dense,
    this.contentPadding,
    this.activeColor,
    this.checkColor,
    this.tristate = false,
    this.shape,
    this.side,
    this.tileColor,
    this.selectedTileColor,
    this.visualDensity,
    this.enableFeedback,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.autofocus = false,
    this.focusNode,
    this.checkboxShape,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedTitle =
        titleText ?? (tomId != null ? resolveResource(context, 'label') : null);
    final effectiveTitle = title ??
        (resolvedTitle != null
            ? Text(resolvedTitle)
            : const SizedBox.shrink());

    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: effectiveTitle,
      subtitle: subtitle,
      secondary: secondary,
      isThreeLine: isThreeLine,
      dense: dense,
      contentPadding: contentPadding,
      activeColor: activeColor,
      checkColor: checkColor,
      tristate: tristate,
      shape: shape,
      side: side,
      tileColor: tileColor,
      selectedTileColor: selectedTileColor,
      visualDensity: visualDensity,
      enableFeedback: enableFeedback,
      controlAffinity: controlAffinity,
      autofocus: autofocus,
      focusNode: focusNode,
      checkboxShape: checkboxShape,
    );
  }
}

/// Tom wrapper for [RadioListTile].
///
/// Adds ID, group, authorization, and resource resolution for title.
class TomRadioListTile<T> extends TomToggleBase {
  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final Widget? title;
  final String? titleText;
  final Widget? subtitle;
  final Widget? secondary;
  final bool isThreeLine;
  final bool? dense;
  final EdgeInsetsGeometry? contentPadding;
  final Color? activeColor;
  final Color? tileColor;
  final Color? selectedTileColor;
  final VisualDensity? visualDensity;
  final bool? enableFeedback;
  final ListTileControlAffinity controlAffinity;
  final bool toggleable;
  final bool autofocus;
  final FocusNode? focusNode;
  final ShapeBorder? shape;
  final WidgetStateProperty<Color?>? fillColor;

  const TomRadioListTile({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.value,
    this.groupValue,
    this.onChanged,
    this.title,
    this.titleText,
    this.subtitle,
    this.secondary,
    this.isThreeLine = false,
    this.dense,
    this.contentPadding,
    this.activeColor,
    this.tileColor,
    this.selectedTileColor,
    this.visualDensity,
    this.enableFeedback,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.toggleable = false,
    this.autofocus = false,
    this.focusNode,
    this.shape,
    this.fillColor,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedTitle =
        titleText ?? (tomId != null ? resolveResource(context, 'label') : null);
    final effectiveTitle = title ??
        (resolvedTitle != null
            ? Text(resolvedTitle)
            : const SizedBox.shrink());

    return RadioListTile<T>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      title: effectiveTitle,
      subtitle: subtitle,
      secondary: secondary,
      isThreeLine: isThreeLine,
      dense: dense,
      contentPadding: contentPadding,
      activeColor: activeColor,
      tileColor: tileColor,
      selectedTileColor: selectedTileColor,
      visualDensity: visualDensity,
      enableFeedback: enableFeedback,
      controlAffinity: controlAffinity,
      toggleable: toggleable,
      autofocus: autofocus,
      focusNode: focusNode,
      shape: shape,
      fillColor: fillColor,
    );
  }
}

/// Tom wrapper for [ToggleButtons].
///
/// Adds ID, group, authorization.
class TomToggleButtons extends TomToggleBase {
  final List<Widget> children;
  final List<bool> isSelected;
  final ValueChanged<int>? onPressed;
  final Color? color;
  final Color? selectedColor;
  final Color? disabledColor;
  final Color? fillColor;
  final Color? focusColor;
  final Color? highlightColor;
  final Color? hoverColor;
  final Color? splashColor;
  final List<FocusNode>? focusNodes;
  final bool renderBorder;
  final Color? borderColor;
  final Color? selectedBorderColor;
  final Color? disabledBorderColor;
  final double? borderWidth;
  final BorderRadius? borderRadius;
  final Axis direction;
  final VerticalDirection verticalDirection;
  final BoxConstraints? constraints;
  final TextStyle? textStyle;

  const TomToggleButtons({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.children,
    required this.isSelected,
    this.onPressed,
    this.color,
    this.selectedColor,
    this.disabledColor,
    this.fillColor,
    this.focusColor,
    this.highlightColor,
    this.hoverColor,
    this.splashColor,
    this.focusNodes,
    this.renderBorder = true,
    this.borderColor,
    this.selectedBorderColor,
    this.disabledBorderColor,
    this.borderWidth,
    this.borderRadius,
    this.direction = Axis.horizontal,
    this.verticalDirection = VerticalDirection.down,
    this.constraints,
    this.textStyle,
  });

  @override
  Widget buildContent(BuildContext context) {
    return ToggleButtons(
      isSelected: isSelected,
      onPressed: onPressed,
      color: color,
      selectedColor: selectedColor,
      disabledColor: disabledColor,
      fillColor: fillColor,
      focusColor: focusColor,
      highlightColor: highlightColor,
      hoverColor: hoverColor,
      splashColor: splashColor,
      focusNodes: focusNodes,
      renderBorder: renderBorder,
      borderColor: borderColor,
      selectedBorderColor: selectedBorderColor,
      disabledBorderColor: disabledBorderColor,
      borderWidth: borderWidth,
      borderRadius: borderRadius,
      direction: direction,
      verticalDirection: verticalDirection,
      constraints: constraints,
      textStyle: textStyle,
      children: children,
    );
  }
}

/// Tom wrapper for [CupertinoSwitch].
///
/// iOS-style toggle switch. Adds ID, group, authorization,
/// and resource resolution.
class TomCupertinoSwitch extends TomToggleBase {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeTrackColor;
  final Color? thumbColor;
  final Color? trackColor;
  final DragStartBehavior dragStartBehavior;
  final bool applyTheme;
  final Color? focusColor;
  final Color? onLabelColor;
  final Color? offLabelColor;
  final FocusNode? focusNode;
  final bool autofocus;

  const TomCupertinoSwitch({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.value,
    required this.onChanged,
    this.activeTrackColor,
    this.thumbColor,
    this.trackColor,
    this.dragStartBehavior = DragStartBehavior.start,
    this.applyTheme = false,
    this.focusColor,
    this.onLabelColor,
    this.offLabelColor,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoSwitch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: activeTrackColor,
      thumbColor: thumbColor,
      trackColor: trackColor,
      dragStartBehavior: dragStartBehavior,
      applyTheme: applyTheme,
      focusColor: focusColor,
      onLabelColor: onLabelColor,
      offLabelColor: offLabelColor,
      focusNode: focusNode,
      autofocus: autofocus,
    );
  }
}

// ============================================================================
// Section II Toggles — Cupertino checkbox and radio
// ============================================================================

/// Tom wrapper for [CupertinoCheckbox].
///
/// Cupertino-styled checkbox. Auth for readonly/hidden.
class TomCupertinoCheckbox extends TomToggleBase {
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? checkColor;
  final bool tristate;
  final Color? focusColor;
  final FocusNode? focusNode;
  final bool autofocus;
  final BorderSide? side;
  final OutlinedBorder? shape;
  final String? semanticLabel;

  const TomCupertinoCheckbox({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.value,
    this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.checkColor,
    this.tristate = false,
    this.focusColor,
    this.focusNode,
    this.autofocus = false,
    this.side,
    this.shape,
    this.semanticLabel,
  });

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoCheckbox(
      value: value,
      onChanged: onChanged,
      activeColor: activeColor,
      inactiveColor: inactiveColor,
      checkColor: checkColor,
      tristate: tristate,
      focusColor: focusColor,
      focusNode: focusNode,
      autofocus: autofocus,
      side: side,
      shape: shape,
      semanticLabel: semanticLabel,
    );
  }
}

/// Tom wrapper for [CupertinoRadio].
///
/// Cupertino-styled radio button. Auth for readonly/hidden.
class TomCupertinoRadio<T> extends TomToggleBase {
  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final MouseCursor? mouseCursor;
  final bool toggleable;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? fillColor;
  final Color? focusColor;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool useCheckmarkStyle;

  const TomCupertinoRadio({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.value,
    required this.groupValue,
    this.onChanged,
    this.mouseCursor,
    this.toggleable = false,
    this.activeColor,
    this.inactiveColor,
    this.fillColor,
    this.focusColor,
    this.focusNode,
    this.autofocus = false,
    this.useCheckmarkStyle = false,
  });

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoRadio<T>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      mouseCursor: mouseCursor,
      toggleable: toggleable,
      activeColor: activeColor,
      inactiveColor: inactiveColor,
      fillColor: fillColor,
      focusColor: focusColor,
      focusNode: focusNode,
      autofocus: autofocus,
      useCheckmarkStyle: useCheckmarkStyle,
    );
  }
}
