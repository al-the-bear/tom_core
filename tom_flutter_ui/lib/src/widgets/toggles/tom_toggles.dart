import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_construction_helpers.dart';
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

  // Pre-resolved resource values
  late final Color? _resolvedActiveColor;
  late final Color? _resolvedActiveTrackColor;
  late final Color? _resolvedInactiveThumbColor;
  late final Color? _resolvedInactiveTrackColor;
  late final double? _resolvedSplashRadius;
  late final bool _resolvedAutofocus;

  TomSwitch({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required this.value,
    ValueChanged<bool>? onChanged,
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
  }) : onChanged = InScopeBuilder(scope: scope).wrap1n(onChanged) {
    _resolvedActiveColor = activeColor ?? TomCtr.color(basePath, 'activeColor');
    _resolvedActiveTrackColor =
        activeTrackColor ?? TomCtr.color(basePath, 'activeTrackColor');
    _resolvedInactiveThumbColor =
        inactiveThumbColor ?? TomCtr.color(basePath, 'inactiveThumbColor');
    _resolvedInactiveTrackColor =
        inactiveTrackColor ?? TomCtr.color(basePath, 'inactiveTrackColor');
    _resolvedSplashRadius =
        splashRadius ?? TomCtr.doubleVal(basePath, 'splashRadius');
    _resolvedAutofocus = TomCtr.boolVal(basePath, 'autofocus') ?? autofocus;
  }

  @override
  Widget buildContent(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: _resolvedActiveColor,
      activeTrackColor: _resolvedActiveTrackColor,
      inactiveThumbColor: _resolvedInactiveThumbColor,
      inactiveTrackColor: _resolvedInactiveTrackColor,
      activeThumbImage: activeThumbImage,
      inactiveThumbImage: inactiveThumbImage,
      thumbColor: thumbColor,
      trackColor: trackColor,
      trackOutlineColor: trackOutlineColor,
      trackOutlineWidth: trackOutlineWidth,
      thumbIcon: thumbIcon,
      focusNode: focusNode,
      autofocus: _resolvedAutofocus,
      overlayColor: overlayColor,
      splashRadius: _resolvedSplashRadius,
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

  // Pre-resolved resource values
  late final Color? _resolvedActiveColor;
  late final Color? _resolvedCheckColor;
  late final Color? _resolvedFocusColor;
  late final Color? _resolvedHoverColor;
  late final double? _resolvedSplashRadius;
  late final bool _resolvedTristate;
  late final bool _resolvedIsError;
  late final bool _resolvedAutofocus;
  late final VisualDensity? _resolvedVisualDensity;
  late final OutlinedBorder? _resolvedShape;
  late final BorderSide? _resolvedSide;

  TomCheckbox({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required this.value,
    ValueChanged<bool?>? onChanged,
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
  }) : onChanged = InScopeBuilder(scope: scope).wrap1n(onChanged) {
    _resolvedActiveColor = activeColor ?? TomCtr.color(basePath, 'activeColor');
    _resolvedCheckColor = checkColor ?? TomCtr.color(basePath, 'checkColor');
    _resolvedFocusColor = focusColor ?? TomCtr.color(basePath, 'focusColor');
    _resolvedHoverColor = hoverColor ?? TomCtr.color(basePath, 'hoverColor');
    _resolvedSplashRadius =
        splashRadius ?? TomCtr.doubleVal(basePath, 'splashRadius');
    _resolvedTristate = TomCtr.boolVal(basePath, 'tristate') ?? tristate;
    _resolvedIsError = TomCtr.boolVal(basePath, 'isError') ?? isError;
    _resolvedAutofocus = TomCtr.boolVal(basePath, 'autofocus') ?? autofocus;
    _resolvedVisualDensity =
        visualDensity ?? _resolveVisualDensity('visualDensity');
    _resolvedShape = shape ?? _resolveShapeBorder('shape') as OutlinedBorder?;
    _resolvedSide = side ?? _resolveBorderSide('side');
  }

  @override
  Widget buildContent(BuildContext context) {
    return Checkbox(
      value: value,
      onChanged: onChanged,
      tristate: _resolvedTristate,
      activeColor: _resolvedActiveColor,
      fillColor: fillColor,
      checkColor: _resolvedCheckColor,
      focusColor: _resolvedFocusColor,
      hoverColor: _resolvedHoverColor,
      overlayColor: overlayColor,
      splashRadius: _resolvedSplashRadius,
      visualDensity: _resolvedVisualDensity,
      shape: _resolvedShape,
      side: _resolvedSide,
      isError: _resolvedIsError,
      focusNode: focusNode,
      autofocus: _resolvedAutofocus,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }

  BorderSide? _resolveBorderSide(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderSide(basePath!, suffix);
  }

  VisualDensity? _resolveVisualDensity(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveVisualDensity(basePath!, suffix);
  }
}

/// The `enabled` flag to forward to a Flutter radio.
///
/// Grouping lives on a [RadioGroup] ancestor, so a radio's interactivity can
/// no longer be withheld by passing a null `onChanged` — the ancestor supplies
/// the callback for every radio beneath it. `enabled: false` is the only lever
/// the widget itself still holds, which is why a withheld [TomAuthState] has
/// to pull it: [TomStateStyle] wraps the readonly and disabled treatments in
/// an `AbsorbPointer`, and that stops the pointer but not the keyboard, which
/// [RadioGroup] makes an active input path.
///
/// `null` defers to the ancestor, which is what [Radio.enabled] documents as
/// its own default.
bool? _radioEnabled(bool? explicit, TomAuthState auth) =>
    explicit ?? (auth == TomAuthState.full ? null : false);

/// Tom wrapper for [Radio].
///
/// Adds ID, group, authorization, and resource resolution for label.
///
/// Selection is read from the enclosing [RadioGroup] of the same type
/// argument: the radio is selected when its [value] equals the group's
/// `groupValue`, and picking it calls the group's `onChanged`. Without such an
/// ancestor the radio renders unselected and inert — that is [Radio]'s own
/// behaviour, not a Tom restriction. [TomRadioGroup] supplies the ancestor for
/// the common list-of-options case.
class TomRadio<T> extends TomToggleBase {
  final T value;

  /// Whether the radio accepts input, forwarded to [Radio.enabled].
  ///
  /// Leave it null to follow the enclosing [RadioGroup]; see [_radioEnabled]
  /// for why a withheld [TomAuthState] overrides that default.
  final bool? enabled;

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

  // Pre-resolved resource values
  late final Color? _resolvedActiveColor;
  late final Color? _resolvedFocusColor;
  late final Color? _resolvedHoverColor;
  late final double? _resolvedSplashRadius;
  late final bool _resolvedToggleable;
  late final bool _resolvedAutofocus;
  late final VisualDensity? _resolvedVisualDensity;

  TomRadio({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required this.value,
    this.enabled,
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
  }) {
    _resolvedActiveColor = activeColor ?? TomCtr.color(basePath, 'activeColor');
    _resolvedFocusColor = focusColor ?? TomCtr.color(basePath, 'focusColor');
    _resolvedHoverColor = hoverColor ?? TomCtr.color(basePath, 'hoverColor');
    _resolvedSplashRadius =
        splashRadius ?? TomCtr.doubleVal(basePath, 'splashRadius');
    _resolvedToggleable = TomCtr.boolVal(basePath, 'toggleable') ?? toggleable;
    _resolvedAutofocus = TomCtr.boolVal(basePath, 'autofocus') ?? autofocus;
    _resolvedVisualDensity =
        visualDensity ?? _resolveVisualDensity('visualDensity');
  }

  @override
  Widget buildContent(BuildContext context) {
    return Radio<T>(
      value: value,
      enabled: _radioEnabled(enabled, effectiveAuthState),
      activeColor: _resolvedActiveColor,
      fillColor: fillColor,
      focusColor: _resolvedFocusColor,
      hoverColor: _resolvedHoverColor,
      overlayColor: overlayColor,
      splashRadius: _resolvedSplashRadius,
      visualDensity: _resolvedVisualDensity,
      toggleable: _resolvedToggleable,
      focusNode: focusNode,
      autofocus: _resolvedAutofocus,
    );
  }

  VisualDensity? _resolveVisualDensity(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveVisualDensity(basePath!, suffix);
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

  // Pre-resolved resource values
  late final String _resolvedTitle;
  late final bool _resolvedIsThreeLine;
  late final bool? _resolvedDense;
  late final Color? _resolvedActiveColor;
  late final Color? _resolvedActiveTrackColor;
  late final Color? _resolvedInactiveThumbColor;
  late final Color? _resolvedInactiveTrackColor;
  late final Color? _resolvedTileColor;
  late final Color? _resolvedSelectedTileColor;
  late final Color? _resolvedHoverColor;
  late final bool _resolvedAutofocus;
  late final bool? _resolvedEnableFeedback;
  late final EdgeInsetsGeometry? _resolvedContentPadding;
  late final ShapeBorder? _resolvedShape;
  late final VisualDensity? _resolvedVisualDensity;

  TomSwitchListTile({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required this.value,
    ValueChanged<bool>? onChanged,
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
  }) : onChanged = InScopeBuilder(scope: scope).wrap1n(onChanged) {
    _resolvedTitle =
        titleText ??
        TomCtr.textOrNull(basePath, 'titleText') ??
        TomCtr.textOrFail(basePath, 'label', supersededBy: title);
    _resolvedIsThreeLine =
        TomCtr.boolVal(basePath, 'isThreeLine') ?? isThreeLine;
    _resolvedDense = dense ?? TomCtr.boolVal(basePath, 'dense');
    _resolvedActiveColor = activeColor ?? TomCtr.color(basePath, 'activeColor');
    _resolvedActiveTrackColor =
        activeTrackColor ?? TomCtr.color(basePath, 'activeTrackColor');
    _resolvedInactiveThumbColor =
        inactiveThumbColor ?? TomCtr.color(basePath, 'inactiveThumbColor');
    _resolvedInactiveTrackColor =
        inactiveTrackColor ?? TomCtr.color(basePath, 'inactiveTrackColor');
    _resolvedTileColor = tileColor ?? TomCtr.color(basePath, 'tileColor');
    _resolvedSelectedTileColor =
        selectedTileColor ?? TomCtr.color(basePath, 'selectedTileColor');
    _resolvedHoverColor = hoverColor ?? TomCtr.color(basePath, 'hoverColor');
    _resolvedAutofocus = TomCtr.boolVal(basePath, 'autofocus') ?? autofocus;
    _resolvedEnableFeedback =
        enableFeedback ?? TomCtr.boolVal(basePath, 'enableFeedback');
    _resolvedContentPadding =
        contentPadding ?? TomCtr.edgeInsets(basePath, 'contentPadding');
    _resolvedShape = shape ?? _resolveShapeBorder('shape');
    _resolvedVisualDensity =
        visualDensity ?? _resolveVisualDensity('visualDensity');
  }

  @override
  Widget buildContent(BuildContext context) {
    final effectiveTitle = title ?? Text(_resolvedTitle);

    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: effectiveTitle,
      subtitle: subtitle,
      secondary: secondary,
      isThreeLine: _resolvedIsThreeLine,
      dense: _resolvedDense,
      contentPadding: _resolvedContentPadding,
      activeThumbColor: _resolvedActiveColor,
      activeTrackColor: _resolvedActiveTrackColor,
      inactiveThumbColor: _resolvedInactiveThumbColor,
      inactiveTrackColor: _resolvedInactiveTrackColor,
      autofocus: _resolvedAutofocus,
      focusNode: focusNode,
      controlAffinity: controlAffinity,
      shape: _resolvedShape,
      tileColor: _resolvedTileColor,
      selectedTileColor: _resolvedSelectedTileColor,
      visualDensity: _resolvedVisualDensity,
      enableFeedback: _resolvedEnableFeedback,
      hoverColor: _resolvedHoverColor,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }

  VisualDensity? _resolveVisualDensity(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveVisualDensity(basePath!, suffix);
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

  // Pre-resolved resource values
  late final String _resolvedTitle;
  late final bool _resolvedIsThreeLine;
  late final bool? _resolvedDense;
  late final bool _resolvedTristate;
  late final Color? _resolvedActiveColor;
  late final Color? _resolvedCheckColor;
  late final Color? _resolvedTileColor;
  late final Color? _resolvedSelectedTileColor;
  late final bool? _resolvedEnableFeedback;
  late final bool _resolvedAutofocus;
  late final EdgeInsetsGeometry? _resolvedContentPadding;
  late final ShapeBorder? _resolvedShape;
  late final BorderSide? _resolvedSide;
  late final VisualDensity? _resolvedVisualDensity;
  late final OutlinedBorder? _resolvedCheckboxShape;

  TomCheckboxListTile({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required this.value,
    ValueChanged<bool?>? onChanged,
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
  }) : onChanged = InScopeBuilder(scope: scope).wrap1n(onChanged) {
    _resolvedTitle =
        titleText ??
        TomCtr.textOrNull(basePath, 'titleText') ??
        TomCtr.textOrFail(basePath, 'label', supersededBy: title);
    _resolvedIsThreeLine =
        TomCtr.boolVal(basePath, 'isThreeLine') ?? isThreeLine;
    _resolvedDense = dense ?? TomCtr.boolVal(basePath, 'dense');
    _resolvedTristate = TomCtr.boolVal(basePath, 'tristate') ?? tristate;
    _resolvedActiveColor = activeColor ?? TomCtr.color(basePath, 'activeColor');
    _resolvedCheckColor = checkColor ?? TomCtr.color(basePath, 'checkColor');
    _resolvedTileColor = tileColor ?? TomCtr.color(basePath, 'tileColor');
    _resolvedSelectedTileColor =
        selectedTileColor ?? TomCtr.color(basePath, 'selectedTileColor');
    _resolvedEnableFeedback =
        enableFeedback ?? TomCtr.boolVal(basePath, 'enableFeedback');
    _resolvedAutofocus = TomCtr.boolVal(basePath, 'autofocus') ?? autofocus;
    _resolvedContentPadding =
        contentPadding ?? TomCtr.edgeInsets(basePath, 'contentPadding');
    _resolvedShape = shape ?? _resolveShapeBorder('shape');
    _resolvedSide = side ?? _resolveBorderSide('side');
    _resolvedVisualDensity =
        visualDensity ?? _resolveVisualDensity('visualDensity');
    _resolvedCheckboxShape =
        checkboxShape ??
        _resolveShapeBorder('checkboxShape') as OutlinedBorder?;
  }

  @override
  Widget buildContent(BuildContext context) {
    final effectiveTitle = title ?? Text(_resolvedTitle);

    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: effectiveTitle,
      subtitle: subtitle,
      secondary: secondary,
      isThreeLine: _resolvedIsThreeLine,
      dense: _resolvedDense,
      contentPadding: _resolvedContentPadding,
      activeColor: _resolvedActiveColor,
      checkColor: _resolvedCheckColor,
      tristate: _resolvedTristate,
      shape: _resolvedShape,
      side: _resolvedSide,
      tileColor: _resolvedTileColor,
      selectedTileColor: _resolvedSelectedTileColor,
      visualDensity: _resolvedVisualDensity,
      enableFeedback: _resolvedEnableFeedback,
      controlAffinity: controlAffinity,
      autofocus: _resolvedAutofocus,
      focusNode: focusNode,
      checkboxShape: _resolvedCheckboxShape,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }

  BorderSide? _resolveBorderSide(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderSide(basePath!, suffix);
  }

  VisualDensity? _resolveVisualDensity(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveVisualDensity(basePath!, suffix);
  }
}

/// Tom wrapper for [RadioListTile].
///
/// Adds ID, group, authorization, and resource resolution for title.
///
/// Like [TomRadio], selection comes from the enclosing [RadioGroup] of the
/// same type argument rather than from a `groupValue` of its own.
class TomRadioListTile<T> extends TomToggleBase {
  final T value;

  /// Whether the tile accepts input, forwarded to [RadioListTile.enabled].
  ///
  /// Leave it null to follow the enclosing [RadioGroup]; see [_radioEnabled]
  /// for why a withheld [TomAuthState] overrides that default.
  final bool? enabled;

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

  // Pre-resolved resource values
  late final String _resolvedTitle;
  late final Color? _resolvedActiveColor;
  late final Color? _resolvedTileColor;
  late final Color? _resolvedSelectedTileColor;
  late final EdgeInsetsGeometry? _resolvedContentPadding;
  late final bool? _resolvedDense;
  late final bool _resolvedIsThreeLine;
  late final VisualDensity? _resolvedVisualDensity;
  late final bool? _resolvedEnableFeedback;
  late final bool _resolvedToggleable;
  late final bool _resolvedAutofocus;
  late final ShapeBorder? _resolvedShape;

  TomRadioListTile({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required this.value,
    this.enabled,
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
  }) {
    _resolvedTitle =
        titleText ?? TomCtr.textOrFail(basePath, 'label', supersededBy: title);
    _resolvedActiveColor = activeColor ?? TomCtr.color(basePath, 'activeColor');
    _resolvedTileColor = tileColor ?? TomCtr.color(basePath, 'tileColor');
    _resolvedSelectedTileColor =
        selectedTileColor ?? TomCtr.color(basePath, 'selectedTileColor');
    _resolvedContentPadding =
        contentPadding ?? TomCtr.edgeInsets(basePath, 'contentPadding');
    _resolvedDense = dense ?? TomCtr.boolVal(basePath, 'dense');
    _resolvedIsThreeLine =
        TomCtr.boolVal(basePath, 'isThreeLine') ?? isThreeLine;
    _resolvedVisualDensity =
        visualDensity ?? _resolveVisualDensity('visualDensity');
    _resolvedEnableFeedback =
        enableFeedback ?? TomCtr.boolVal(basePath, 'enableFeedback');
    _resolvedToggleable = TomCtr.boolVal(basePath, 'toggleable') ?? toggleable;
    _resolvedAutofocus = TomCtr.boolVal(basePath, 'autofocus') ?? autofocus;
    _resolvedShape = shape ?? _resolveShapeBorder('shape');
  }

  @override
  Widget buildContent(BuildContext context) {
    final effectiveTitle = title ?? Text(_resolvedTitle);

    return RadioListTile<T>(
      value: value,
      enabled: _radioEnabled(enabled, effectiveAuthState),
      title: effectiveTitle,
      subtitle: subtitle,
      secondary: secondary,
      isThreeLine: _resolvedIsThreeLine,
      dense: _resolvedDense,
      contentPadding: _resolvedContentPadding,
      activeColor: _resolvedActiveColor,
      tileColor: _resolvedTileColor,
      selectedTileColor: _resolvedSelectedTileColor,
      visualDensity: _resolvedVisualDensity,
      enableFeedback: _resolvedEnableFeedback,
      controlAffinity: controlAffinity,
      toggleable: _resolvedToggleable,
      autofocus: _resolvedAutofocus,
      focusNode: focusNode,
      shape: _resolvedShape,
      fillColor: fillColor,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }

  VisualDensity? _resolveVisualDensity(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveVisualDensity(basePath!, suffix);
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

  // Pre-resolved resource values
  late final Color? _resolvedColor;
  late final Color? _resolvedSelectedColor;
  late final Color? _resolvedDisabledColor;
  late final Color? _resolvedFillColor;
  late final Color? _resolvedFocusColor;
  late final Color? _resolvedHighlightColor;
  late final Color? _resolvedHoverColor;
  late final Color? _resolvedSplashColor;
  late final Color? _resolvedBorderColor;
  late final Color? _resolvedSelectedBorderColor;
  late final Color? _resolvedDisabledBorderColor;
  late final double? _resolvedBorderWidth;

  TomToggleButtons({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required this.children,
    required this.isSelected,
    ValueChanged<int>? onPressed,
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
  }) : onPressed = InScopeBuilder(scope: scope).wrap1n(onPressed) {
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
    _resolvedSelectedColor =
        selectedColor ?? TomCtr.color(basePath, 'selectedColor');
    _resolvedDisabledColor =
        disabledColor ?? TomCtr.color(basePath, 'disabledColor');
    _resolvedFillColor = fillColor ?? TomCtr.color(basePath, 'fillColor');
    _resolvedFocusColor = focusColor ?? TomCtr.color(basePath, 'focusColor');
    _resolvedHighlightColor =
        highlightColor ?? TomCtr.color(basePath, 'highlightColor');
    _resolvedHoverColor = hoverColor ?? TomCtr.color(basePath, 'hoverColor');
    _resolvedSplashColor = splashColor ?? TomCtr.color(basePath, 'splashColor');
    _resolvedBorderColor = borderColor ?? TomCtr.color(basePath, 'borderColor');
    _resolvedSelectedBorderColor =
        selectedBorderColor ?? TomCtr.color(basePath, 'selectedBorderColor');
    _resolvedDisabledBorderColor =
        disabledBorderColor ?? TomCtr.color(basePath, 'disabledBorderColor');
    _resolvedBorderWidth =
        borderWidth ?? TomCtr.doubleVal(basePath, 'borderWidth');
  }

  @override
  Widget buildContent(BuildContext context) {
    return ToggleButtons(
      isSelected: isSelected,
      onPressed: onPressed,
      color: _resolvedColor,
      selectedColor: _resolvedSelectedColor,
      disabledColor: _resolvedDisabledColor,
      fillColor: _resolvedFillColor,
      focusColor: _resolvedFocusColor,
      highlightColor: _resolvedHighlightColor,
      hoverColor: _resolvedHoverColor,
      splashColor: _resolvedSplashColor,
      focusNodes: focusNodes,
      renderBorder: renderBorder,
      borderColor: _resolvedBorderColor,
      selectedBorderColor: _resolvedSelectedBorderColor,
      disabledBorderColor: _resolvedDisabledBorderColor,
      borderWidth: _resolvedBorderWidth,
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

  // Pre-resolved resource values
  late final Color? _resolvedActiveTrackColor;
  late final Color? _resolvedThumbColor;
  late final Color? _resolvedTrackColor;
  late final Color? _resolvedFocusColor;
  late final Color? _resolvedOnLabelColor;
  late final Color? _resolvedOffLabelColor;

  TomCupertinoSwitch({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required this.value,
    ValueChanged<bool>? onChanged,
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
  }) : onChanged = InScopeBuilder(scope: scope).wrap1n(onChanged) {
    _resolvedActiveTrackColor =
        activeTrackColor ?? TomCtr.color(basePath, 'activeTrackColor');
    _resolvedThumbColor = thumbColor ?? TomCtr.color(basePath, 'thumbColor');
    _resolvedTrackColor = trackColor ?? TomCtr.color(basePath, 'trackColor');
    _resolvedFocusColor = focusColor ?? TomCtr.color(basePath, 'focusColor');
    _resolvedOnLabelColor =
        onLabelColor ?? TomCtr.color(basePath, 'onLabelColor');
    _resolvedOffLabelColor =
        offLabelColor ?? TomCtr.color(basePath, 'offLabelColor');
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoSwitch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: _resolvedActiveTrackColor,
      thumbColor: _resolvedThumbColor,
      inactiveTrackColor: _resolvedTrackColor,
      dragStartBehavior: dragStartBehavior,
      applyTheme: applyTheme,
      focusColor: _resolvedFocusColor,
      onLabelColor: _resolvedOnLabelColor,
      offLabelColor: _resolvedOffLabelColor,
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

  // Pre-resolved resource values
  late final Color? _resolvedActiveColor;
  late final Color? _resolvedInactiveColor;
  late final Color? _resolvedCheckColor;
  late final Color? _resolvedFocusColor;
  late final String? _resolvedSemanticLabel;
  late final BorderSide? _resolvedSide;
  late final OutlinedBorder? _resolvedShape;

  TomCupertinoCheckbox({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required this.value,
    ValueChanged<bool?>? onChanged,
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
  }) : onChanged = InScopeBuilder(scope: scope).wrap1n(onChanged) {
    _resolvedActiveColor = activeColor ?? TomCtr.color(basePath, 'activeColor');
    _resolvedInactiveColor =
        inactiveColor ?? TomCtr.color(basePath, 'inactiveColor');
    _resolvedCheckColor = checkColor ?? TomCtr.color(basePath, 'checkColor');
    _resolvedFocusColor = focusColor ?? TomCtr.color(basePath, 'focusColor');
    _resolvedSemanticLabel =
        semanticLabel ?? TomCtr.textOrNull(basePath, 'semanticLabel');
    _resolvedSide = side ?? _resolveBorderSide('side');
    _resolvedShape = shape ?? _resolveShapeBorder('shape') as OutlinedBorder?;
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoCheckbox(
      value: value,
      onChanged: onChanged,
      activeColor: _resolvedActiveColor,
      fillColor: WidgetStatePropertyAll(_resolvedInactiveColor),
      checkColor: _resolvedCheckColor,
      tristate: tristate,
      focusColor: _resolvedFocusColor,
      focusNode: focusNode,
      autofocus: autofocus,
      side: _resolvedSide,
      shape: _resolvedShape,
      semanticLabel: _resolvedSemanticLabel,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }

  BorderSide? _resolveBorderSide(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderSide(basePath!, suffix);
  }
}

/// Tom wrapper for [CupertinoRadio].
///
/// Cupertino-styled radio button. Auth for readonly/hidden.
///
/// Like [TomRadio], selection comes from the enclosing [RadioGroup] of the
/// same type argument rather than from a `groupValue` of its own.
class TomCupertinoRadio<T> extends TomToggleBase {
  final T value;

  /// Whether the radio accepts input, forwarded to [CupertinoRadio.enabled].
  ///
  /// Leave it null to follow the enclosing [RadioGroup]; see [_radioEnabled]
  /// for why a withheld [TomAuthState] overrides that default.
  final bool? enabled;

  final MouseCursor? mouseCursor;
  final bool toggleable;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? fillColor;
  final Color? focusColor;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool useCheckmarkStyle;

  // Pre-resolved resource values
  late final Color? _resolvedActiveColor;
  late final Color? _resolvedInactiveColor;
  late final Color? _resolvedFillColor;
  late final Color? _resolvedFocusColor;

  TomCupertinoRadio({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required this.value,
    this.enabled,
    this.mouseCursor,
    this.toggleable = false,
    this.activeColor,
    this.inactiveColor,
    this.fillColor,
    this.focusColor,
    this.focusNode,
    this.autofocus = false,
    this.useCheckmarkStyle = false,
  }) {
    _resolvedActiveColor = activeColor ?? TomCtr.color(basePath, 'activeColor');
    _resolvedInactiveColor =
        inactiveColor ?? TomCtr.color(basePath, 'inactiveColor');
    _resolvedFillColor = fillColor ?? TomCtr.color(basePath, 'fillColor');
    _resolvedFocusColor = focusColor ?? TomCtr.color(basePath, 'focusColor');
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoRadio<T>(
      value: value,
      enabled: _radioEnabled(enabled, effectiveAuthState),
      mouseCursor: mouseCursor,
      toggleable: toggleable,
      activeColor: _resolvedActiveColor,
      inactiveColor: _resolvedInactiveColor,
      fillColor: _resolvedFillColor,
      focusColor: _resolvedFocusColor,
      focusNode: focusNode,
      autofocus: autofocus,
      useCheckmarkStyle: useCheckmarkStyle,
    );
  }
}
