import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_style_resolvers.dart';

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
    // Phase 2: Resolve optional color parameters from resources
    final resolvedActiveColor =
        activeColor ?? resolveColorOrNull('activeColor');
    final resolvedActiveTrackColor =
        activeTrackColor ?? resolveColorOrNull('activeTrackColor');
    final resolvedInactiveThumbColor =
        inactiveThumbColor ?? resolveColorOrNull('inactiveThumbColor');
    final resolvedInactiveTrackColor =
        inactiveTrackColor ?? resolveColorOrNull('inactiveTrackColor');
    final resolvedSplashRadius =
        splashRadius ?? resolveDoubleOrNull('splashRadius');
    final resolvedAutofocus =
      resolveBoolOrNull('autofocus') ?? autofocus;

    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: resolvedActiveColor,
      activeTrackColor: resolvedActiveTrackColor,
      inactiveThumbColor: resolvedInactiveThumbColor,
      inactiveTrackColor: resolvedInactiveTrackColor,
      activeThumbImage: activeThumbImage,
      inactiveThumbImage: inactiveThumbImage,
      thumbColor: thumbColor,
      trackColor: trackColor,
      trackOutlineColor: trackOutlineColor,
      trackOutlineWidth: trackOutlineWidth,
      thumbIcon: thumbIcon,
      focusNode: focusNode,
      autofocus: resolvedAutofocus,
      overlayColor: overlayColor,
      splashRadius: resolvedSplashRadius,
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
    // Phase 2: Resolve optional color parameters from resources
    final resolvedActiveColor =
        activeColor ?? resolveColorOrNull('activeColor');
    final resolvedCheckColor =
        checkColor ?? resolveColorOrNull('checkColor');
    final resolvedFocusColor =
        focusColor ?? resolveColorOrNull('focusColor');
    final resolvedHoverColor =
        hoverColor ?? resolveColorOrNull('hoverColor');
    final resolvedSplashRadius =
        splashRadius ?? resolveDoubleOrNull('splashRadius');
    final resolvedTristate =
        resolveBoolOrNull('tristate') ?? tristate;
    final resolvedIsError =
        resolveBoolOrNull('isError') ?? isError;
    final resolvedAutofocus =
        resolveBoolOrNull('autofocus') ?? autofocus;

    return Checkbox(
      value: value,
      onChanged: onChanged,
      tristate: resolvedTristate,
      activeColor: resolvedActiveColor,
      fillColor: fillColor,
      checkColor: resolvedCheckColor,
      focusColor: resolvedFocusColor,
      hoverColor: resolvedHoverColor,
      overlayColor: overlayColor,
      splashRadius: resolvedSplashRadius,
      visualDensity: visualDensity ?? _resolveVisualDensity('visualDensity'),
      shape: shape ?? _resolveShapeBorder('shape') as OutlinedBorder?,
      side: side ?? _resolveBorderSide('side'),
      isError: resolvedIsError,
      focusNode: focusNode,
      autofocus: resolvedAutofocus,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath, suffix);
  }

  BorderSide? _resolveBorderSide(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderSide(basePath, suffix);
  }

  VisualDensity? _resolveVisualDensity(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveVisualDensity(basePath, suffix);
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
    // Phase 2: Resolve optional color parameters from resources
    final resolvedActiveColor =
        activeColor ?? resolveColorOrNull('activeColor');
    final resolvedFocusColor =
        focusColor ?? resolveColorOrNull('focusColor');
    final resolvedHoverColor =
        hoverColor ?? resolveColorOrNull('hoverColor');
    final resolvedSplashRadius =
        splashRadius ?? resolveDoubleOrNull('splashRadius');
    final resolvedToggleable =
      resolveBoolOrNull('toggleable') ?? toggleable;
    final resolvedAutofocus =
      resolveBoolOrNull('autofocus') ?? autofocus;
    final resolvedVisualDensity =
      visualDensity ?? _resolveVisualDensity('visualDensity');

    return Radio<T>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: resolvedActiveColor,
      fillColor: fillColor,
      focusColor: resolvedFocusColor,
      hoverColor: resolvedHoverColor,
      overlayColor: overlayColor,
      splashRadius: resolvedSplashRadius,
      visualDensity: resolvedVisualDensity,
      toggleable: resolvedToggleable,
      focusNode: focusNode,
      autofocus: resolvedAutofocus,
    );
  }

  VisualDensity? _resolveVisualDensity(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveVisualDensity(basePath, suffix);
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
    final resolvedTitle = titleText ??
      resolveResourceOrNull('titleText') ??
      resolveResourceOrFail('label');
    final effectiveTitle = title ?? Text(resolvedTitle);

    // Phase 2: Resolve optional color parameters from resources
    final resolvedIsThreeLine =
      resolveBoolOrNull('isThreeLine') ?? isThreeLine;
    final resolvedDense = dense ?? resolveBoolOrNull('dense');
    final resolvedActiveColor =
        activeColor ?? resolveColorOrNull('activeColor');
    final resolvedActiveTrackColor =
        activeTrackColor ?? resolveColorOrNull('activeTrackColor');
    final resolvedInactiveThumbColor =
        inactiveThumbColor ?? resolveColorOrNull('inactiveThumbColor');
    final resolvedInactiveTrackColor =
        inactiveTrackColor ?? resolveColorOrNull('inactiveTrackColor');
    final resolvedTileColor =
        tileColor ?? resolveColorOrNull('tileColor');
    final resolvedSelectedTileColor =
        selectedTileColor ?? resolveColorOrNull('selectedTileColor');
    final resolvedHoverColor =
        hoverColor ?? resolveColorOrNull('hoverColor');
    final resolvedAutofocus =
        resolveBoolOrNull('autofocus') ?? autofocus;
    final resolvedEnableFeedback =
        enableFeedback ?? resolveBoolOrNull('enableFeedback');
    final resolvedContentPadding =
        contentPadding ?? resolveEdgeInsetsOrNull('contentPadding');
    final resolvedShape = shape ?? _resolveShapeBorder('shape');
    final resolvedVisualDensity =
        visualDensity ?? _resolveVisualDensity('visualDensity');

    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: effectiveTitle,
      subtitle: subtitle,
      secondary: secondary,
      isThreeLine: resolvedIsThreeLine,
      dense: resolvedDense,
      contentPadding: resolvedContentPadding,
      activeColor: resolvedActiveColor,
      activeTrackColor: resolvedActiveTrackColor,
      inactiveThumbColor: resolvedInactiveThumbColor,
      inactiveTrackColor: resolvedInactiveTrackColor,
      autofocus: resolvedAutofocus,
      focusNode: focusNode,
      controlAffinity: controlAffinity,
      shape: resolvedShape,
      tileColor: resolvedTileColor,
      selectedTileColor: resolvedSelectedTileColor,
      visualDensity: resolvedVisualDensity,
      enableFeedback: resolvedEnableFeedback,
      hoverColor: resolvedHoverColor,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath, suffix);
  }

  VisualDensity? _resolveVisualDensity(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveVisualDensity(basePath, suffix);
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
    final resolvedTitle = titleText ??
      resolveResourceOrNull('titleText') ??
      resolveResourceOrFail('label');
    final effectiveTitle = title ?? Text(resolvedTitle);

    // Phase 2: Resolve optional color parameters from resources
    final resolvedIsThreeLine =
      resolveBoolOrNull('isThreeLine') ?? isThreeLine;
    final resolvedDense = dense ?? resolveBoolOrNull('dense');
    final resolvedTristate =
      resolveBoolOrNull('tristate') ?? tristate;
    final resolvedActiveColor =
        activeColor ?? resolveColorOrNull('activeColor');
    final resolvedCheckColor =
        checkColor ?? resolveColorOrNull('checkColor');
    final resolvedTileColor =
        tileColor ?? resolveColorOrNull('tileColor');
    final resolvedSelectedTileColor =
        selectedTileColor ?? resolveColorOrNull('selectedTileColor');
    final resolvedEnableFeedback =
        enableFeedback ?? resolveBoolOrNull('enableFeedback');
    final resolvedAutofocus =
        resolveBoolOrNull('autofocus') ?? autofocus;
    final resolvedContentPadding =
        contentPadding ?? resolveEdgeInsetsOrNull('contentPadding');
    final resolvedShape = shape ?? _resolveShapeBorder('shape');
    final resolvedSide = side ?? _resolveBorderSide('side');
    final resolvedVisualDensity =
        visualDensity ?? _resolveVisualDensity('visualDensity');
    final resolvedCheckboxShape =
        checkboxShape ?? _resolveShapeBorder('checkboxShape') as OutlinedBorder?;

    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: effectiveTitle,
      subtitle: subtitle,
      secondary: secondary,
      isThreeLine: resolvedIsThreeLine,
      dense: resolvedDense,
      contentPadding: resolvedContentPadding,
      activeColor: resolvedActiveColor,
      checkColor: resolvedCheckColor,
      tristate: resolvedTristate,
      shape: resolvedShape,
      side: resolvedSide,
      tileColor: resolvedTileColor,
      selectedTileColor: resolvedSelectedTileColor,
      visualDensity: resolvedVisualDensity,
      enableFeedback: resolvedEnableFeedback,
      controlAffinity: controlAffinity,
      autofocus: resolvedAutofocus,
      focusNode: focusNode,
      checkboxShape: resolvedCheckboxShape,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath, suffix);
  }

  BorderSide? _resolveBorderSide(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderSide(basePath, suffix);
  }

  VisualDensity? _resolveVisualDensity(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveVisualDensity(basePath, suffix);
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
    final resolvedTitle = titleText ?? resolveResourceOrFail('label');
    final effectiveTitle = title ?? Text(resolvedTitle);

    // Phase 2: Resolve optional parameters from resources
    final resolvedActiveColor =
        activeColor ?? resolveColorOrNull('activeColor');
    final resolvedTileColor =
        tileColor ?? resolveColorOrNull('tileColor');
    final resolvedSelectedTileColor =
        selectedTileColor ?? resolveColorOrNull('selectedTileColor');
    final resolvedContentPadding =
        contentPadding ?? resolveEdgeInsetsOrNull('contentPadding');
    final resolvedDense = dense ?? resolveBoolOrNull('dense');
    final resolvedIsThreeLine =
        resolveBoolOrNull('isThreeLine') ?? isThreeLine;
    final resolvedVisualDensity =
        visualDensity ?? _resolveVisualDensity('visualDensity');
    final resolvedEnableFeedback =
        enableFeedback ?? resolveBoolOrNull('enableFeedback');
    final resolvedToggleable =
        resolveBoolOrNull('toggleable') ?? toggleable;
    final resolvedAutofocus =
        resolveBoolOrNull('autofocus') ?? autofocus;
    final resolvedShape = shape ?? _resolveShapeBorder('shape');

    return RadioListTile<T>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      title: effectiveTitle,
      subtitle: subtitle,
      secondary: secondary,
      isThreeLine: resolvedIsThreeLine,
      dense: resolvedDense,
      contentPadding: resolvedContentPadding,
      activeColor: resolvedActiveColor,
      tileColor: resolvedTileColor,
      selectedTileColor: resolvedSelectedTileColor,
      visualDensity: resolvedVisualDensity,
      enableFeedback: resolvedEnableFeedback,
      controlAffinity: controlAffinity,
      toggleable: resolvedToggleable,
      autofocus: resolvedAutofocus,
      focusNode: focusNode,
      shape: resolvedShape,
      fillColor: fillColor,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath, suffix);
  }

  VisualDensity? _resolveVisualDensity(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveVisualDensity(basePath, suffix);
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
    // Phase 2: Resolve optional color parameters from resources
    final resolvedColor = color ?? resolveColorOrNull('color');
    final resolvedSelectedColor =
        selectedColor ?? resolveColorOrNull('selectedColor');
    final resolvedDisabledColor =
        disabledColor ?? resolveColorOrNull('disabledColor');
    final resolvedFillColor =
        fillColor ?? resolveColorOrNull('fillColor');
    final resolvedFocusColor =
        focusColor ?? resolveColorOrNull('focusColor');
    final resolvedHighlightColor =
        highlightColor ?? resolveColorOrNull('highlightColor');
    final resolvedHoverColor =
        hoverColor ?? resolveColorOrNull('hoverColor');
    final resolvedSplashColor =
        splashColor ?? resolveColorOrNull('splashColor');
    final resolvedBorderColor =
        borderColor ?? resolveColorOrNull('borderColor');
    final resolvedSelectedBorderColor =
        selectedBorderColor ?? resolveColorOrNull('selectedBorderColor');
    final resolvedDisabledBorderColor =
        disabledBorderColor ?? resolveColorOrNull('disabledBorderColor');
    final resolvedBorderWidth =
        borderWidth ?? resolveDoubleOrNull('borderWidth');

    return ToggleButtons(
      isSelected: isSelected,
      onPressed: onPressed,
      color: resolvedColor,
      selectedColor: resolvedSelectedColor,
      disabledColor: resolvedDisabledColor,
      fillColor: resolvedFillColor,
      focusColor: resolvedFocusColor,
      highlightColor: resolvedHighlightColor,
      hoverColor: resolvedHoverColor,
      splashColor: resolvedSplashColor,
      focusNodes: focusNodes,
      renderBorder: renderBorder,
      borderColor: resolvedBorderColor,
      selectedBorderColor: resolvedSelectedBorderColor,
      disabledBorderColor: resolvedDisabledBorderColor,
      borderWidth: resolvedBorderWidth,
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
    this.onChanged,
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
    // Phase 2: Resolve optional color parameters from resources
    final resolvedActiveTrackColor =
        activeTrackColor ?? resolveColorOrNull('activeTrackColor');
    final resolvedThumbColor =
        thumbColor ?? resolveColorOrNull('thumbColor');
    final resolvedTrackColor =
        trackColor ?? resolveColorOrNull('trackColor');
    final resolvedFocusColor =
        focusColor ?? resolveColorOrNull('focusColor');
    final resolvedOnLabelColor =
        onLabelColor ?? resolveColorOrNull('onLabelColor');
    final resolvedOffLabelColor =
        offLabelColor ?? resolveColorOrNull('offLabelColor');

    return CupertinoSwitch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: resolvedActiveTrackColor,
      thumbColor: resolvedThumbColor,
      trackColor: resolvedTrackColor,
      dragStartBehavior: dragStartBehavior,
      applyTheme: applyTheme,
      focusColor: resolvedFocusColor,
      onLabelColor: resolvedOnLabelColor,
      offLabelColor: resolvedOffLabelColor,
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
    // Phase 2: Resolve optional color parameters from resources
    final resolvedActiveColor =
        activeColor ?? resolveColorOrNull('activeColor');
    final resolvedInactiveColor =
        inactiveColor ?? resolveColorOrNull('inactiveColor');
    final resolvedCheckColor =
        checkColor ?? resolveColorOrNull('checkColor');
    final resolvedFocusColor =
        focusColor ?? resolveColorOrNull('focusColor');
    final resolvedSemanticLabel =
      semanticLabel ?? resolveResourceOrNull('semanticLabel');
    final resolvedSide = side ?? _resolveBorderSide('side');
    final resolvedShape =
      shape ?? _resolveShapeBorder('shape') as OutlinedBorder?;

    return CupertinoCheckbox(
      value: value,
      onChanged: onChanged,
      activeColor: resolvedActiveColor,
      inactiveColor: resolvedInactiveColor,
      checkColor: resolvedCheckColor,
      tristate: tristate,
      focusColor: resolvedFocusColor,
      focusNode: focusNode,
      autofocus: autofocus,
      side: resolvedSide,
      shape: resolvedShape,
      semanticLabel: resolvedSemanticLabel,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath, suffix);
  }

  BorderSide? _resolveBorderSide(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderSide(basePath, suffix);
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
    // Phase 2: Resolve optional color parameters from resources
    final resolvedActiveColor =
        activeColor ?? resolveColorOrNull('activeColor');
    final resolvedInactiveColor =
        inactiveColor ?? resolveColorOrNull('inactiveColor');
    final resolvedFillColor =
        fillColor ?? resolveColorOrNull('fillColor');
    final resolvedFocusColor =
        focusColor ?? resolveColorOrNull('focusColor');

    return CupertinoRadio<T>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      mouseCursor: mouseCursor,
      toggleable: toggleable,
      activeColor: resolvedActiveColor,
      inactiveColor: resolvedInactiveColor,
      fillColor: resolvedFillColor,
      focusColor: resolvedFocusColor,
      focusNode: focusNode,
      autofocus: autofocus,
      useCheckmarkStyle: useCheckmarkStyle,
    );
  }
}
