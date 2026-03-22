import 'package:flutter/gestures.dart';
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
    super.tomStyleVariant,
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
    super.tomStyleVariant,
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
    super.tomStyleVariant,
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
