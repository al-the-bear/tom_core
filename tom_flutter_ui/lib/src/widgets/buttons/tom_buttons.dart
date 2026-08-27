import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../groups/tom_widget_mixin.dart';
import '../../widget_base/tom_construction_helpers.dart';
import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_style_resolvers.dart';

/// Tom wrapper for [ElevatedButton].
///
/// Adds ID, group, authorization, and resource resolution to the standard
/// Flutter [ElevatedButton]. Exposes the full underlying API.
///
/// When [label] is not provided, resolves from resources using suffix 'label'.
/// When [icon] is not provided, resolves from resources using suffix 'icon'.
class TomElevatedButton extends TomButtonBase {
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onHover;
  final ValueChanged<bool>? onFocusChange;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;
  final Widget? icon;
  final Widget? child;
  final String? label;

  // Pre-resolved resource values
  late final String _resolvedLabel;
  late final Widget? _resolvedIcon;
  late final ButtonStyle? _resolvedStyle;

  TomElevatedButton({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ValueChanged<bool>? onHover,
    ValueChanged<bool>? onFocusChange,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.icon,
    this.child,
    this.label,
  })  : onPressed = InScopeBuilder(scope: scope).wrap0n(onPressed),
        onLongPress = InScopeBuilder(scope: scope).wrap0n(onLongPress),
        onHover = InScopeBuilder(scope: scope).wrap1n(onHover),
        onFocusChange = InScopeBuilder(scope: scope).wrap1n(onFocusChange) {
    _resolvedLabel = label ?? TomCtr.textOrFail(basePath, 'label', supersededBy: child);
    _resolvedIcon = icon ?? _buildResolvedIcon();
    _resolvedStyle = style ?? _resolveStyle();
  }

  @override
  Widget buildContent(BuildContext context) {
    final buttonChild = child ?? Text(_resolvedLabel);

    if (_resolvedIcon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        onLongPress: onLongPress,
        onHover: onHover,
        onFocusChange: onFocusChange,
        style: _resolvedStyle,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        icon: _resolvedIcon,
        label: buttonChild,
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: _resolvedStyle,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      child: buttonChild,
    );
  }

  /// Builds an Icon widget from resolved icon data, or null if not available.
  Widget? _buildResolvedIcon() {
    final iconData = TomCtr.icon(basePath, 'icon');
    if (iconData == null) return null;
    return Icon(iconData);
  }

  /// Resolves ButtonStyle from resources.
  ButtonStyle? _resolveStyle() {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveButtonStyle(basePath!, 'style');
  }
}

/// Tom wrapper for [TextButton].
///
/// When [label] is not provided, resolves from resources using suffix 'label'.
/// When [icon] is not provided, resolves from resources using suffix 'icon'.
class TomTextButton extends TomButtonBase {
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onHover;
  final ValueChanged<bool>? onFocusChange;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;
  final Widget? icon;
  final Widget? child;
  final String? label;

  // Pre-resolved resource values
  late final String _resolvedLabel;
  late final Widget? _resolvedIcon;
  late final ButtonStyle? _resolvedStyle;

  TomTextButton({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ValueChanged<bool>? onHover,
    ValueChanged<bool>? onFocusChange,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.icon,
    this.child,
    this.label,
  })  : onPressed = InScopeBuilder(scope: scope).wrap0n(onPressed),
        onLongPress = InScopeBuilder(scope: scope).wrap0n(onLongPress),
        onHover = InScopeBuilder(scope: scope).wrap1n(onHover),
        onFocusChange = InScopeBuilder(scope: scope).wrap1n(onFocusChange) {
    _resolvedLabel = label ?? TomCtr.textOrFail(basePath, 'label', supersededBy: child);
    _resolvedIcon = icon ?? _buildResolvedIcon();
    _resolvedStyle = style ?? _resolveStyle();
  }

  @override
  Widget buildContent(BuildContext context) {
    final buttonChild = child ?? Text(_resolvedLabel);

    if (_resolvedIcon != null) {
      return TextButton.icon(
        onPressed: onPressed,
        onLongPress: onLongPress,
        onHover: onHover,
        onFocusChange: onFocusChange,
        style: _resolvedStyle,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        icon: _resolvedIcon,
        label: buttonChild,
      );
    }

    return TextButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: _resolvedStyle,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      child: buttonChild,
    );
  }

  Widget? _buildResolvedIcon() {
    final iconData = TomCtr.icon(basePath, 'icon');
    if (iconData == null) return null;
    return Icon(iconData);
  }

  /// Resolves ButtonStyle from resources.
  ButtonStyle? _resolveStyle() {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveButtonStyle(basePath!, 'style');
  }
}

/// Tom wrapper for [OutlinedButton].
///
/// When [label] is not provided, resolves from resources using suffix 'label'.
/// When [icon] is not provided, resolves from resources using suffix 'icon'.
class TomOutlinedButton extends TomButtonBase {
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onHover;
  final ValueChanged<bool>? onFocusChange;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;
  final Widget? icon;
  final Widget? child;
  final String? label;

  // Pre-resolved resource values
  late final String _resolvedLabel;
  late final Widget? _resolvedIcon;
  late final ButtonStyle? _resolvedStyle;

  TomOutlinedButton({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ValueChanged<bool>? onHover,
    ValueChanged<bool>? onFocusChange,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.icon,
    this.child,
    this.label,
  })  : onPressed = InScopeBuilder(scope: scope).wrap0n(onPressed),
        onLongPress = InScopeBuilder(scope: scope).wrap0n(onLongPress),
        onHover = InScopeBuilder(scope: scope).wrap1n(onHover),
        onFocusChange = InScopeBuilder(scope: scope).wrap1n(onFocusChange) {
    _resolvedLabel = label ?? TomCtr.textOrFail(basePath, 'label', supersededBy: child);
    _resolvedIcon = icon ?? _buildResolvedIcon();
    _resolvedStyle = style ?? _resolveStyle();
  }

  @override
  Widget buildContent(BuildContext context) {
    final buttonChild = child ?? Text(_resolvedLabel);

    if (_resolvedIcon != null) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        onLongPress: onLongPress,
        onHover: onHover,
        onFocusChange: onFocusChange,
        style: _resolvedStyle,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        icon: _resolvedIcon,
        label: buttonChild,
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: _resolvedStyle,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      child: buttonChild,
    );
  }

  Widget? _buildResolvedIcon() {
    final iconData = TomCtr.icon(basePath, 'icon');
    if (iconData == null) return null;
    return Icon(iconData);
  }

  /// Resolves ButtonStyle from resources.
  ButtonStyle? _resolveStyle() {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveButtonStyle(basePath!, 'style');
  }
}

/// Tom wrapper for [FilledButton].
///
/// When [label] is not provided, resolves from resources using suffix 'label'.
/// When [icon] is not provided, resolves from resources using suffix 'icon'.
class TomFilledButton extends TomButtonBase {
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onHover;
  final ValueChanged<bool>? onFocusChange;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;
  final Widget? icon;
  final Widget? child;
  final String? label;
  final bool tonal;

  // Pre-resolved resource values
  late final String _resolvedLabel;
  late final Widget? _resolvedIcon;
  late final ButtonStyle? _resolvedStyle;

  TomFilledButton({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ValueChanged<bool>? onHover,
    ValueChanged<bool>? onFocusChange,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.icon,
    this.child,
    this.label,
    this.tonal = false,
  })  : onPressed = InScopeBuilder(scope: scope).wrap0n(onPressed),
        onLongPress = InScopeBuilder(scope: scope).wrap0n(onLongPress),
        onHover = InScopeBuilder(scope: scope).wrap1n(onHover),
        onFocusChange = InScopeBuilder(scope: scope).wrap1n(onFocusChange) {
    _resolvedLabel = label ?? TomCtr.textOrFail(basePath, 'label', supersededBy: child);
    _resolvedIcon = icon ?? _buildResolvedIcon();
    _resolvedStyle = style ?? _resolveStyle();
  }

  @override
  Widget buildContent(BuildContext context) {
    final buttonChild = child ?? Text(_resolvedLabel);

    if (tonal) {
      if (_resolvedIcon != null) {
        return FilledButton.tonalIcon(
          onPressed: onPressed,
          onLongPress: onLongPress,
          onHover: onHover,
          onFocusChange: onFocusChange,
          style: _resolvedStyle,
          focusNode: focusNode,
          autofocus: autofocus,
          clipBehavior: clipBehavior,
          icon: _resolvedIcon,
          label: buttonChild,
        );
      }
      return FilledButton.tonal(
        onPressed: onPressed,
        onLongPress: onLongPress,
        onHover: onHover,
        onFocusChange: onFocusChange,
        style: _resolvedStyle,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        child: buttonChild,
      );
    }

    if (_resolvedIcon != null) {
      return FilledButton.icon(
        onPressed: onPressed,
        onLongPress: onLongPress,
        onHover: onHover,
        onFocusChange: onFocusChange,
        style: _resolvedStyle,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        icon: _resolvedIcon,
        label: buttonChild,
      );
    }

    return FilledButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: _resolvedStyle,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      child: buttonChild,
    );
  }

  Widget? _buildResolvedIcon() {
    final iconData = TomCtr.icon(basePath, 'icon');
    if (iconData == null) return null;
    return Icon(iconData);
  }

  /// Resolves ButtonStyle from resources.
  ButtonStyle? _resolveStyle() {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveButtonStyle(basePath!, 'style');
  }
}

/// Variant type for [TomFloatingActionButton].
enum _FABVariant { regular, small, large, extended }

/// Tom wrapper for [FloatingActionButton].
class TomFloatingActionButton extends TomButtonBase {
  final VoidCallback? onPressed;
  final Widget? child;
  final String? tooltip;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final Color? focusColor;
  final Color? hoverColor;
  final Color? splashColor;
  final double? elevation;
  final double? focusElevation;
  final double? hoverElevation;
  final double? highlightElevation;
  final double? disabledElevation;
  final ShapeBorder? shape;
  final Clip clipBehavior;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool? isExtended;
  final bool mini;
  final Widget? icon;
  final Widget? extendedIconLabelChild;
  final String? label;
  final Object? heroTag;
  final _FABVariant _variant;

  // Pre-resolved resource values
  late final String? _resolvedTooltip;
  late final Color? _resolvedForegroundColor;
  late final Color? _resolvedBackgroundColor;
  late final Color? _resolvedFocusColor;
  late final Color? _resolvedHoverColor;
  late final Color? _resolvedSplashColor;
  late final double? _resolvedElevation;
  late final double? _resolvedFocusElevation;
  late final double? _resolvedHoverElevation;
  late final double? _resolvedHighlightElevation;
  late final double? _resolvedDisabledElevation;
  late final ShapeBorder? _resolvedShape;
  late final bool _resolvedAutofocus;
  late final bool _resolvedMini;
  late final bool? _resolvedIsExtended;
  late final String? _resolvedLabel;
  late final Widget? _resolvedIcon;
  late final Widget? _resolvedChild;

  TomFloatingActionButton({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    VoidCallback? onPressed,
    this.child,
    this.tooltip,
    this.foregroundColor,
    this.backgroundColor,
    this.focusColor,
    this.hoverColor,
    this.splashColor,
    this.elevation,
    this.focusElevation,
    this.hoverElevation,
    this.highlightElevation,
    this.disabledElevation,
    this.shape,
    this.clipBehavior = Clip.none,
    this.autofocus = false,
    this.focusNode,
    this.isExtended,
    this.mini = false,
    this.icon,
    this.label,
    this.heroTag,
  })  : onPressed = InScopeBuilder(scope: scope).wrap0n(onPressed),
        _variant = _FABVariant.regular,
        extendedIconLabelChild = null {
    _resolvedTooltip = tooltip ?? TomCtr.textOrNull(basePath, 'tooltip');
    _resolvedForegroundColor = foregroundColor ?? TomCtr.color(basePath, 'foregroundColor');
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedFocusColor = focusColor ?? TomCtr.color(basePath, 'focusColor');
    _resolvedHoverColor = hoverColor ?? TomCtr.color(basePath, 'hoverColor');
    _resolvedSplashColor = splashColor ?? TomCtr.color(basePath, 'splashColor');
    _resolvedElevation = elevation ?? TomCtr.doubleVal(basePath, 'elevation');
    _resolvedFocusElevation = focusElevation ?? TomCtr.doubleVal(basePath, 'focusElevation');
    _resolvedHoverElevation = hoverElevation ?? TomCtr.doubleVal(basePath, 'hoverElevation');
    _resolvedHighlightElevation = highlightElevation ?? TomCtr.doubleVal(basePath, 'highlightElevation');
    _resolvedDisabledElevation = disabledElevation ?? TomCtr.doubleVal(basePath, 'disabledElevation');
    _resolvedShape = shape ?? _resolveShapeBorder('shape');
    _resolvedAutofocus = TomCtr.boolVal(basePath, 'autofocus') ?? autofocus;
    _resolvedMini = TomCtr.boolVal(basePath, 'mini') ?? mini;
    _resolvedIsExtended = isExtended ?? TomCtr.boolVal(basePath, 'isExtended');
    _resolvedLabel = label ?? TomCtr.textOrNull(basePath, 'label');
    _resolvedIcon = _resolveIconWidget();
    _resolvedChild = _resolveChild();
  }

  /// Creates a small floating action button.
  TomFloatingActionButton.small({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    VoidCallback? onPressed,
    this.child,
    this.tooltip,
    this.foregroundColor,
    this.backgroundColor,
    this.focusColor,
    this.hoverColor,
    this.splashColor,
    this.elevation,
    this.focusElevation,
    this.hoverElevation,
    this.highlightElevation,
    this.disabledElevation,
    this.shape,
    this.clipBehavior = Clip.none,
    this.autofocus = false,
    this.focusNode,
    this.heroTag,
  })  : onPressed = InScopeBuilder(scope: scope).wrap0n(onPressed),
        _variant = _FABVariant.small,
        isExtended = null,
        mini = false,
        icon = null,
        label = null,
        extendedIconLabelChild = null {
    _resolvedTooltip = tooltip ?? TomCtr.textOrNull(basePath, 'tooltip');
    _resolvedForegroundColor = foregroundColor ?? TomCtr.color(basePath, 'foregroundColor');
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedFocusColor = focusColor ?? TomCtr.color(basePath, 'focusColor');
    _resolvedHoverColor = hoverColor ?? TomCtr.color(basePath, 'hoverColor');
    _resolvedSplashColor = splashColor ?? TomCtr.color(basePath, 'splashColor');
    _resolvedElevation = elevation ?? TomCtr.doubleVal(basePath, 'elevation');
    _resolvedFocusElevation = focusElevation ?? TomCtr.doubleVal(basePath, 'focusElevation');
    _resolvedHoverElevation = hoverElevation ?? TomCtr.doubleVal(basePath, 'hoverElevation');
    _resolvedHighlightElevation = highlightElevation ?? TomCtr.doubleVal(basePath, 'highlightElevation');
    _resolvedDisabledElevation = disabledElevation ?? TomCtr.doubleVal(basePath, 'disabledElevation');
    _resolvedShape = shape ?? _resolveShapeBorder('shape');
    _resolvedAutofocus = TomCtr.boolVal(basePath, 'autofocus') ?? autofocus;
    _resolvedMini = false;
    _resolvedIsExtended = null;
    _resolvedLabel = null;
    _resolvedIcon = null;
    _resolvedChild = _resolveChild();
  }

  /// Creates a large floating action button.
  TomFloatingActionButton.large({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    VoidCallback? onPressed,
    this.child,
    this.tooltip,
    this.foregroundColor,
    this.backgroundColor,
    this.focusColor,
    this.hoverColor,
    this.splashColor,
    this.elevation,
    this.focusElevation,
    this.hoverElevation,
    this.highlightElevation,
    this.disabledElevation,
    this.shape,
    this.clipBehavior = Clip.none,
    this.autofocus = false,
    this.focusNode,
    this.heroTag,
  })  : onPressed = InScopeBuilder(scope: scope).wrap0n(onPressed),
        _variant = _FABVariant.large,
        isExtended = null,
        mini = false,
        icon = null,
        label = null,
        extendedIconLabelChild = null {
    _resolvedTooltip = tooltip ?? TomCtr.textOrNull(basePath, 'tooltip');
    _resolvedForegroundColor = foregroundColor ?? TomCtr.color(basePath, 'foregroundColor');
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedFocusColor = focusColor ?? TomCtr.color(basePath, 'focusColor');
    _resolvedHoverColor = hoverColor ?? TomCtr.color(basePath, 'hoverColor');
    _resolvedSplashColor = splashColor ?? TomCtr.color(basePath, 'splashColor');
    _resolvedElevation = elevation ?? TomCtr.doubleVal(basePath, 'elevation');
    _resolvedFocusElevation = focusElevation ?? TomCtr.doubleVal(basePath, 'focusElevation');
    _resolvedHoverElevation = hoverElevation ?? TomCtr.doubleVal(basePath, 'hoverElevation');
    _resolvedHighlightElevation = highlightElevation ?? TomCtr.doubleVal(basePath, 'highlightElevation');
    _resolvedDisabledElevation = disabledElevation ?? TomCtr.doubleVal(basePath, 'disabledElevation');
    _resolvedShape = shape ?? _resolveShapeBorder('shape');
    _resolvedAutofocus = TomCtr.boolVal(basePath, 'autofocus') ?? autofocus;
    _resolvedMini = false;
    _resolvedIsExtended = null;
    _resolvedLabel = null;
    _resolvedIcon = null;
    _resolvedChild = _resolveChild();
  }

  /// Creates an extended floating action button with icon and label.
  TomFloatingActionButton.extended({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    VoidCallback? onPressed,
    this.label,
    this.icon,
    this.tooltip,
    this.foregroundColor,
    this.backgroundColor,
    this.focusColor,
    this.hoverColor,
    this.splashColor,
    this.elevation,
    this.focusElevation,
    this.hoverElevation,
    this.highlightElevation,
    this.disabledElevation,
    this.shape,
    this.clipBehavior = Clip.none,
    this.autofocus = false,
    this.focusNode,
    this.isExtended,
    this.extendedIconLabelChild,
    this.heroTag,
  })  : onPressed = InScopeBuilder(scope: scope).wrap0n(onPressed),
        _variant = _FABVariant.extended,
        child = null,
        mini = false {
    _resolvedTooltip = tooltip ?? TomCtr.textOrNull(basePath, 'tooltip');
    _resolvedForegroundColor = foregroundColor ?? TomCtr.color(basePath, 'foregroundColor');
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedFocusColor = focusColor ?? TomCtr.color(basePath, 'focusColor');
    _resolvedHoverColor = hoverColor ?? TomCtr.color(basePath, 'hoverColor');
    _resolvedSplashColor = splashColor ?? TomCtr.color(basePath, 'splashColor');
    _resolvedElevation = elevation ?? TomCtr.doubleVal(basePath, 'elevation');
    _resolvedFocusElevation = focusElevation ?? TomCtr.doubleVal(basePath, 'focusElevation');
    _resolvedHoverElevation = hoverElevation ?? TomCtr.doubleVal(basePath, 'hoverElevation');
    _resolvedHighlightElevation = highlightElevation ?? TomCtr.doubleVal(basePath, 'highlightElevation');
    _resolvedDisabledElevation = disabledElevation ?? TomCtr.doubleVal(basePath, 'disabledElevation');
    _resolvedShape = shape ?? _resolveShapeBorder('shape');
    _resolvedAutofocus = TomCtr.boolVal(basePath, 'autofocus') ?? autofocus;
    _resolvedMini = false;
    _resolvedIsExtended = isExtended ?? TomCtr.boolVal(basePath, 'isExtended');
    _resolvedLabel = label ?? TomCtr.textOrNull(basePath, 'label');
    _resolvedIcon = _resolveIconWidget();
    _resolvedChild = null;
  }

  /// Resolves the child widget from parameter or resources.
  Widget? _resolveChild() {
    if (child != null) return child;
    final iconData = TomCtr.icon(basePath, 'icon');
    if (iconData != null) return Icon(iconData);
    return null;
  }

  /// Resolves the icon widget from parameter or resources.
  Widget? _resolveIconWidget() {
    if (icon != null) return icon;
    final iconData = TomCtr.icon(basePath, 'icon');
    if (iconData != null) return Icon(iconData);
    return null;
  }

  @override
  Widget buildContent(BuildContext context) {
    // Tooltip is always optional

    switch (_variant) {
      case _FABVariant.extended:
        // Extended FAB requires a label
        return FloatingActionButton.extended(
          onPressed: onPressed,
          tooltip: _resolvedTooltip,
          foregroundColor: _resolvedForegroundColor,
          backgroundColor: _resolvedBackgroundColor,
          focusColor: _resolvedFocusColor,
          hoverColor: _resolvedHoverColor,
          splashColor: _resolvedSplashColor,
          heroTag: heroTag,
          elevation: _resolvedElevation,
          focusElevation: _resolvedFocusElevation,
          hoverElevation: _resolvedHoverElevation,
          highlightElevation: _resolvedHighlightElevation,
          disabledElevation: _resolvedDisabledElevation,
          shape: _resolvedShape,
          clipBehavior: clipBehavior,
          autofocus: _resolvedAutofocus,
          focusNode: focusNode,
          isExtended: _resolvedIsExtended ?? true,
          icon: _resolvedIcon,
          label: extendedIconLabelChild ?? Text(_resolvedLabel!),
        );

      case _FABVariant.small:
        return FloatingActionButton.small(
          onPressed: onPressed,
          tooltip: _resolvedTooltip,
          foregroundColor: _resolvedForegroundColor,
          backgroundColor: _resolvedBackgroundColor,
          focusColor: _resolvedFocusColor,
          hoverColor: _resolvedHoverColor,
          splashColor: _resolvedSplashColor,
          heroTag: heroTag,
          elevation: _resolvedElevation,
          focusElevation: _resolvedFocusElevation,
          hoverElevation: _resolvedHoverElevation,
          highlightElevation: _resolvedHighlightElevation,
          disabledElevation: _resolvedDisabledElevation,
          shape: _resolvedShape,
          clipBehavior: clipBehavior,
          autofocus: _resolvedAutofocus,
          focusNode: focusNode,
          child: _resolvedChild,
        );

      case _FABVariant.large:
        return FloatingActionButton.large(
          onPressed: onPressed,
          tooltip: _resolvedTooltip,
          foregroundColor: _resolvedForegroundColor,
          backgroundColor: _resolvedBackgroundColor,
          focusColor: _resolvedFocusColor,
          hoverColor: _resolvedHoverColor,
          splashColor: _resolvedSplashColor,
          heroTag: heroTag,
          elevation: _resolvedElevation,
          focusElevation: _resolvedFocusElevation,
          hoverElevation: _resolvedHoverElevation,
          highlightElevation: _resolvedHighlightElevation,
          disabledElevation: _resolvedDisabledElevation,
          shape: _resolvedShape,
          clipBehavior: clipBehavior,
          autofocus: _resolvedAutofocus,
          focusNode: focusNode,
          child: _resolvedChild,
        );

      case _FABVariant.regular:
        // Legacy behavior: if icon and label are both provided, use extended
        if (_resolvedIcon != null && _resolvedLabel != null) {
          return FloatingActionButton.extended(
            onPressed: onPressed,
            tooltip: _resolvedTooltip,
            foregroundColor: _resolvedForegroundColor,
            backgroundColor: _resolvedBackgroundColor,
            focusColor: _resolvedFocusColor,
            hoverColor: _resolvedHoverColor,
            splashColor: _resolvedSplashColor,
            heroTag: heroTag,
            elevation: _resolvedElevation,
            focusElevation: _resolvedFocusElevation,
            hoverElevation: _resolvedHoverElevation,
            highlightElevation: _resolvedHighlightElevation,
            disabledElevation: _resolvedDisabledElevation,
            shape: _resolvedShape,
            clipBehavior: clipBehavior,
            autofocus: _resolvedAutofocus,
            focusNode: focusNode,
            isExtended: _resolvedIsExtended ?? true,
            icon: _resolvedIcon,
            label: Text(_resolvedLabel),
          );
        }

        // Legacy behavior: if mini is true, use small
        if (_resolvedMini) {
          return FloatingActionButton.small(
            onPressed: onPressed,
            tooltip: _resolvedTooltip,
            foregroundColor: _resolvedForegroundColor,
            backgroundColor: _resolvedBackgroundColor,
            focusColor: _resolvedFocusColor,
            hoverColor: _resolvedHoverColor,
            splashColor: _resolvedSplashColor,
            heroTag: heroTag,
            elevation: _resolvedElevation,
            focusElevation: _resolvedFocusElevation,
            hoverElevation: _resolvedHoverElevation,
            highlightElevation: _resolvedHighlightElevation,
            disabledElevation: _resolvedDisabledElevation,
            shape: _resolvedShape,
            clipBehavior: clipBehavior,
            autofocus: _resolvedAutofocus,
            focusNode: focusNode,
            child: _resolvedChild,
          );
        }

        return FloatingActionButton(
          onPressed: onPressed,
          tooltip: _resolvedTooltip,
          foregroundColor: _resolvedForegroundColor,
          backgroundColor: _resolvedBackgroundColor,
          focusColor: _resolvedFocusColor,
          hoverColor: _resolvedHoverColor,
          splashColor: _resolvedSplashColor,
          heroTag: heroTag,
          elevation: _resolvedElevation,
          focusElevation: _resolvedFocusElevation,
          hoverElevation: _resolvedHoverElevation,
          highlightElevation: _resolvedHighlightElevation,
          disabledElevation: _resolvedDisabledElevation,
          shape: _resolvedShape,
          clipBehavior: clipBehavior,
          autofocus: _resolvedAutofocus,
          focusNode: focusNode,
          mini: _resolvedMini,
          child: _resolvedChild,
        );
    }
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }
}

/// Tom wrapper for [MenuItemButton].
class TomMenuItemButton extends TomButtonBase {
  final VoidCallback? onPressed;
  final VoidCallback? onHover;
  final VoidCallback? onFocusChange;
  final FocusNode? focusNode;
  final MenuSerializableShortcut? shortcut;
  final ButtonStyle? style;
  final bool autofocus;
  final Clip clipBehavior;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final bool closeOnActivate;
  final Widget? child;
  final String? label;

  // Pre-resolved resource values
  late final String _resolvedLabel;
  late final ButtonStyle? _resolvedStyle;

  TomMenuItemButton({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    VoidCallback? onPressed,
    VoidCallback? onHover,
    VoidCallback? onFocusChange,
    this.focusNode,
    this.shortcut,
    this.style,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.leadingIcon,
    this.trailingIcon,
    this.closeOnActivate = true,
    this.child,
    this.label,
  })  : onPressed = InScopeBuilder(scope: scope).wrap0n(onPressed),
        onHover = InScopeBuilder(scope: scope).wrap0n(onHover),
        onFocusChange = InScopeBuilder(scope: scope).wrap0n(onFocusChange) {
    _resolvedLabel = label ?? TomCtr.textOrFail(basePath, 'label', supersededBy: child);
    _resolvedStyle = style ?? _resolveStyle();
  }

  @override
  Widget buildContent(BuildContext context) {
    final buttonChild = child ?? Text(_resolvedLabel);

    return MenuItemButton(
      onPressed: onPressed,
      // Tom exposes these as no-arg callbacks; adapt to the underlying
      // bool-valued hover/focus callbacks so they actually fire (gap §15a).
      onHover: onHover == null ? null : (_) => onHover!(),
      onFocusChange: onFocusChange == null ? null : (_) => onFocusChange!(),
      focusNode: focusNode,
      shortcut: shortcut,
      style: _resolvedStyle,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      closeOnActivate: closeOnActivate,
      child: buttonChild,
    );
  }

  /// Resolves ButtonStyle from resources.
  ButtonStyle? _resolveStyle() {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveButtonStyle(basePath!, 'style');
  }
}

/// Tom wrapper for [SubmenuButton].
class TomSubmenuButton extends TomButtonBase {
  final VoidCallback? onOpen;
  final VoidCallback? onClose;
  final VoidCallback? onHover;
  final VoidCallback? onFocusChange;
  final FocusNode? focusNode;
  final ButtonStyle? style;
  final MenuStyle? menuStyle;
  final Offset? alignmentOffset;
  final Clip clipBehavior;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final List<Widget> menuChildren;
  final Widget? child;
  final String? label;

  // Pre-resolved resource values
  late final String _resolvedLabel;
  late final ButtonStyle? _resolvedStyle;
  late final MenuStyle? _resolvedMenuStyle;
  late final Offset? _resolvedAlignmentOffset;

  TomSubmenuButton({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    VoidCallback? onOpen,
    VoidCallback? onClose,
    VoidCallback? onHover,
    VoidCallback? onFocusChange,
    this.focusNode,
    this.style,
    this.menuStyle,
    this.alignmentOffset,
    this.clipBehavior = Clip.none,
    this.leadingIcon,
    this.trailingIcon,
    required this.menuChildren,
    this.child,
    this.label,
  })  : onOpen = InScopeBuilder(scope: scope).wrap0n(onOpen),
        onClose = InScopeBuilder(scope: scope).wrap0n(onClose),
        onHover = InScopeBuilder(scope: scope).wrap0n(onHover),
        onFocusChange = InScopeBuilder(scope: scope).wrap0n(onFocusChange) {
    _resolvedLabel = label ?? TomCtr.textOrFail(basePath, 'label', supersededBy: child);
    _resolvedStyle = style ?? _resolveStyle();
    _resolvedMenuStyle = menuStyle ?? _resolveMenuStyle();
    _resolvedAlignmentOffset = alignmentOffset ?? _resolveOffset('alignmentOffset');
  }

  @override
  Widget buildContent(BuildContext context) {
    final buttonChild = child ?? Text(_resolvedLabel);

    return SubmenuButton(
      onOpen: onOpen,
      onClose: onClose,
      // Adapt Tom's no-arg callbacks to the bool-valued hover/focus
      // callbacks so they actually fire (gap §15a).
      onHover: onHover == null ? null : (_) => onHover!(),
      onFocusChange: onFocusChange == null ? null : (_) => onFocusChange!(),
      focusNode: focusNode,
      style: _resolvedStyle,
      menuStyle: _resolvedMenuStyle,
      alignmentOffset: _resolvedAlignmentOffset,
      clipBehavior: clipBehavior,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      menuChildren: menuChildren,
      child: buttonChild,
    );
  }

  /// Resolves ButtonStyle from resources.
  ButtonStyle? _resolveStyle() {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveButtonStyle(basePath!, 'style');
  }

  /// Resolves MenuStyle from resources.
  MenuStyle? _resolveMenuStyle() {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveMenuStyle(basePath!, 'menuStyle');
  }

  /// Resolves Offset from resources.
  Offset? _resolveOffset(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveOffset(basePath!, suffix);
  }
}

/// Tom wrapper for [SegmentedButton].
class TomSegmentedButton<T extends Object> extends TomButtonBase {
  final Set<T> selected;
  final List<ButtonSegment<T>> segments;
  final ValueChanged<Set<T>>? onSelectionChanged;
  final bool multiSelectionEnabled;
  final bool emptySelectionAllowed;
  final ButtonStyle? style;
  final bool showSelectedIcon;
  final Widget? selectedIcon;

  // Pre-resolved resource values
  late final ButtonStyle? _resolvedStyle;

  TomSegmentedButton({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required this.segments,
    required this.selected,
    ValueChanged<Set<T>>? onSelectionChanged,
    this.multiSelectionEnabled = false,
    this.emptySelectionAllowed = false,
    this.style,
    this.showSelectedIcon = true,
    this.selectedIcon,
  })  : onSelectionChanged = InScopeBuilder(scope: scope).wrap1n(onSelectionChanged) {
    _resolvedStyle = style ?? _resolveStyle();
  }

  @override
  Widget buildContent(BuildContext context) {
    return SegmentedButton<T>(
      segments: segments,
      selected: selected,
      onSelectionChanged: onSelectionChanged,
      multiSelectionEnabled: multiSelectionEnabled,
      emptySelectionAllowed: emptySelectionAllowed,
      style: _resolvedStyle,
      showSelectedIcon: showSelectedIcon,
      selectedIcon: selectedIcon,
    );
  }

  /// Resolves ButtonStyle from resources.
  ButtonStyle? _resolveStyle() {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveButtonStyle(basePath!, 'style');
  }
}

/// Variant type for [TomIconButton].
enum _IconButtonVariant { regular, filled, filledTonal, outlined }

/// Tom wrapper for [IconButton].
class TomIconButton extends TomButtonBase {
  final VoidCallback? onPressed;
  final double? iconSize;
  final VisualDensity? visualDensity;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;
  final double? splashRadius;
  final Color? color;
  final Color? focusColor;
  final Color? hoverColor;
  final Color? highlightColor;
  final Color? splashColor;
  final Color? disabledColor;
  final bool autofocus;
  final BoxConstraints? constraints;
  final ButtonStyle? style;
  final bool? isSelected;
  final Widget? selectedIcon;
  final Widget? icon;
  final String? tooltip;
  final FocusNode? focusNode;
  final _IconButtonVariant _variant;

  // Pre-resolved resource values
  late final String? _resolvedTooltip;
  late final Widget _resolvedIcon;
  late final double? _resolvedIconSize;
  late final double? _resolvedSplashRadius;
  late final Color? _resolvedColor;
  late final Color? _resolvedFocusColor;
  late final Color? _resolvedHoverColor;
  late final Color? _resolvedHighlightColor;
  late final Color? _resolvedSplashColor;
  late final Color? _resolvedDisabledColor;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final AlignmentGeometry _resolvedAlignment;
  late final BoxConstraints? _resolvedConstraints;
  late final ButtonStyle? _resolvedStyle;

  TomIconButton({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    VoidCallback? onPressed,
    this.iconSize,
    this.visualDensity,
    this.padding,
    this.alignment,
    this.splashRadius,
    this.color,
    this.focusColor,
    this.hoverColor,
    this.highlightColor,
    this.splashColor,
    this.disabledColor,
    this.autofocus = false,
    this.constraints,
    this.style,
    this.isSelected,
    this.selectedIcon,
    this.icon,
    this.tooltip,
    this.focusNode,
  })  : onPressed = InScopeBuilder(scope: scope).wrap0n(onPressed),
        _variant = _IconButtonVariant.regular {
    _initResolvedFields();
  }

  /// Creates a filled icon button.
  TomIconButton.filled({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    VoidCallback? onPressed,
    this.iconSize,
    this.visualDensity,
    this.padding,
    this.alignment,
    this.splashRadius,
    this.color,
    this.focusColor,
    this.hoverColor,
    this.highlightColor,
    this.splashColor,
    this.disabledColor,
    this.autofocus = false,
    this.constraints,
    this.style,
    this.isSelected,
    this.selectedIcon,
    this.icon,
    this.tooltip,
    this.focusNode,
  })  : onPressed = InScopeBuilder(scope: scope).wrap0n(onPressed),
        _variant = _IconButtonVariant.filled {
    _initResolvedFields();
  }

  /// Creates a filled tonal icon button.
  TomIconButton.filledTonal({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    VoidCallback? onPressed,
    this.iconSize,
    this.visualDensity,
    this.padding,
    this.alignment,
    this.splashRadius,
    this.color,
    this.focusColor,
    this.hoverColor,
    this.highlightColor,
    this.splashColor,
    this.disabledColor,
    this.autofocus = false,
    this.constraints,
    this.style,
    this.isSelected,
    this.selectedIcon,
    this.icon,
    this.tooltip,
    this.focusNode,
  })  : onPressed = InScopeBuilder(scope: scope).wrap0n(onPressed),
        _variant = _IconButtonVariant.filledTonal {
    _initResolvedFields();
  }

  /// Creates an outlined icon button.
  TomIconButton.outlined({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    VoidCallback? onPressed,
    this.iconSize,
    this.visualDensity,
    this.padding,
    this.alignment,
    this.splashRadius,
    this.color,
    this.focusColor,
    this.hoverColor,
    this.highlightColor,
    this.splashColor,
    this.disabledColor,
    this.autofocus = false,
    this.constraints,
    this.style,
    this.isSelected,
    this.selectedIcon,
    this.icon,
    this.tooltip,
    this.focusNode,
  })  : onPressed = InScopeBuilder(scope: scope).wrap0n(onPressed),
        _variant = _IconButtonVariant.outlined {
    _initResolvedFields();
  }

  void _initResolvedFields() {
    _resolvedTooltip = tooltip ?? TomCtr.textOrNull(basePath, 'tooltip');
    _resolvedIcon = _resolveIconWidget();
    _resolvedIconSize = iconSize ?? TomCtr.doubleVal(basePath, 'iconSize');
    _resolvedSplashRadius = splashRadius ?? TomCtr.doubleVal(basePath, 'splashRadius');
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
    _resolvedFocusColor = focusColor ?? TomCtr.color(basePath, 'focusColor');
    _resolvedHoverColor = hoverColor ?? TomCtr.color(basePath, 'hoverColor');
    _resolvedHighlightColor = highlightColor ?? TomCtr.color(basePath, 'highlightColor');
    _resolvedSplashColor = splashColor ?? TomCtr.color(basePath, 'splashColor');
    _resolvedDisabledColor = disabledColor ?? TomCtr.color(basePath, 'disabledColor');
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
    _resolvedAlignment = alignment ?? _resolveAlignment('alignment') ?? Alignment.center;
    _resolvedConstraints = constraints ?? _resolveBoxConstraints('constraints');
    _resolvedStyle = style ?? _resolveStyle();
  }

  /// Resolves the icon widget from parameter or resources.
  ///
  /// Resolves through [TomCtr.iconOrFail] rather than [TomCtr.icon] because
  /// here the icon *is* the button: with nothing to fall back to, a missing
  /// one leaves a control that is present and tappable but says nothing about
  /// what it does.
  Widget _resolveIconWidget() {
    if (icon != null) return icon!;
    return Icon(TomCtr.iconOrFail(basePath, 'icon'));
  }

  @override
  Widget buildContent(BuildContext context) {
    switch (_variant) {
      case _IconButtonVariant.filled:
        return IconButton.filled(
          onPressed: onPressed,
          iconSize: _resolvedIconSize,
          visualDensity: visualDensity,
          padding: _resolvedPadding,
          alignment: _resolvedAlignment,
          splashRadius: _resolvedSplashRadius,
          color: _resolvedColor,
          focusColor: _resolvedFocusColor,
          hoverColor: _resolvedHoverColor,
          highlightColor: _resolvedHighlightColor,
          splashColor: _resolvedSplashColor,
          disabledColor: _resolvedDisabledColor,
          autofocus: autofocus,
          constraints: _resolvedConstraints,
          style: _resolvedStyle,
          isSelected: isSelected,
          selectedIcon: selectedIcon,
          icon: _resolvedIcon,
          tooltip: _resolvedTooltip,
          focusNode: focusNode,
        );

      case _IconButtonVariant.filledTonal:
        return IconButton.filledTonal(
          onPressed: onPressed,
          iconSize: _resolvedIconSize,
          visualDensity: visualDensity,
          padding: _resolvedPadding,
          alignment: _resolvedAlignment,
          splashRadius: _resolvedSplashRadius,
          color: _resolvedColor,
          focusColor: _resolvedFocusColor,
          hoverColor: _resolvedHoverColor,
          highlightColor: _resolvedHighlightColor,
          splashColor: _resolvedSplashColor,
          disabledColor: _resolvedDisabledColor,
          autofocus: autofocus,
          constraints: _resolvedConstraints,
          style: _resolvedStyle,
          isSelected: isSelected,
          selectedIcon: selectedIcon,
          icon: _resolvedIcon,
          tooltip: _resolvedTooltip,
          focusNode: focusNode,
        );

      case _IconButtonVariant.outlined:
        return IconButton.outlined(
          onPressed: onPressed,
          iconSize: _resolvedIconSize,
          visualDensity: visualDensity,
          padding: _resolvedPadding,
          alignment: _resolvedAlignment,
          splashRadius: _resolvedSplashRadius,
          color: _resolvedColor,
          focusColor: _resolvedFocusColor,
          hoverColor: _resolvedHoverColor,
          highlightColor: _resolvedHighlightColor,
          splashColor: _resolvedSplashColor,
          disabledColor: _resolvedDisabledColor,
          autofocus: autofocus,
          constraints: _resolvedConstraints,
          style: _resolvedStyle,
          isSelected: isSelected,
          selectedIcon: selectedIcon,
          icon: _resolvedIcon,
          tooltip: _resolvedTooltip,
          focusNode: focusNode,
        );

      case _IconButtonVariant.regular:
        return IconButton(
          onPressed: onPressed,
          iconSize: _resolvedIconSize,
          visualDensity: visualDensity,
          padding: _resolvedPadding,
          alignment: _resolvedAlignment,
          splashRadius: _resolvedSplashRadius,
          color: _resolvedColor,
          focusColor: _resolvedFocusColor,
          hoverColor: _resolvedHoverColor,
          highlightColor: _resolvedHighlightColor,
          splashColor: _resolvedSplashColor,
          disabledColor: _resolvedDisabledColor,
          autofocus: autofocus,
          constraints: _resolvedConstraints,
          style: _resolvedStyle,
          isSelected: isSelected,
          selectedIcon: selectedIcon,
          icon: _resolvedIcon,
          tooltip: _resolvedTooltip,
          focusNode: focusNode,
        );
    }
  }

  /// Resolves ButtonStyle from resources.
  ButtonStyle? _resolveStyle() {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveButtonStyle(basePath!, 'style');
  }

  /// Resolves AlignmentGeometry from resources.
  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
  }

  /// Resolves BoxConstraints from resources.
  BoxConstraints? _resolveBoxConstraints(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBoxConstraints(basePath!, suffix);
  }
}

/// Tom wrapper for [BackButton].
///
/// Adds ID, group, authorization, and resource resolution.
class TomBackButton extends TomButtonBase {
  final VoidCallback? onPressed;
  final Color? color;

  // Pre-resolved resource values
  late final Color? _resolvedColor;

  TomBackButton({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    VoidCallback? onPressed,
    this.color,
  })  : onPressed = InScopeBuilder(scope: scope).wrap0n(onPressed) {
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
  }

  @override
  Widget buildContent(BuildContext context) {
    return BackButton(
      onPressed: onPressed,
      color: _resolvedColor,
    );
  }
}

/// Tom wrapper for [CloseButton].
///
/// Adds ID, group, authorization, and resource resolution.
class TomCloseButton extends TomButtonBase {
  final VoidCallback? onPressed;
  final Color? color;

  // Pre-resolved resource values
  late final Color? _resolvedColor;

  TomCloseButton({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    VoidCallback? onPressed,
    this.color,
  })  : onPressed = InScopeBuilder(scope: scope).wrap0n(onPressed) {
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
  }

  @override
  Widget buildContent(BuildContext context) {
    return CloseButton(
      onPressed: onPressed,
      color: _resolvedColor,
    );
  }
}

/// Tom wrapper for [DropdownMenuEntry] used as an action button.
///
/// Wraps a single dropdown menu entry for use within a [TomDropdownMenu].
/// Adds ID, group, authorization, and resource resolution for the label.
class TomDropdownMenuEntry<T> extends TomButtonBase {
  final T value;
  final String? label;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final bool enabled;
  final ButtonStyle? style;
  final Widget? labelWidget;

  // Pre-resolved resource values
  late final String _resolvedLabel;

  TomDropdownMenuEntry({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required this.value,
    this.label,
    this.leadingIcon,
    this.trailingIcon,
    this.enabled = true,
    this.style,
    this.labelWidget,
  }) {
    _resolvedLabel = label ?? TomCtr.textOrFail(basePath, 'label');
  }

  /// Creates the underlying [DropdownMenuEntry] for use in a [DropdownMenu].
  DropdownMenuEntry<T> toEntry(BuildContext context) {
    final resolvedLabel = label ?? TomCtr.textOrFail(basePath, 'label');

    // Resolve ButtonStyle from resources
    final resolvedStyle = style ?? _resolveStyle();

    return DropdownMenuEntry<T>(
      value: value,
      label: resolvedLabel,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      enabled: enabled,
      style: resolvedStyle,
      labelWidget: labelWidget,
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    // DropdownMenuEntry is not a widget itself — it is used as data within
    // DropdownMenu. This buildContent returns a placeholder that renders
    // the label for preview/accessibility purposes.

    return Text(_resolvedLabel);
  }

  /// Resolves ButtonStyle from resources.
  ButtonStyle? _resolveStyle() {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveButtonStyle(basePath!, 'style');
  }
}

// ============================================================================
// Section II Buttons — Cupertino and additional Material buttons
// ============================================================================

/// Tom wrapper for [CupertinoButton].
///
/// Cupertino parity with ElevatedButton — primary Cupertino button style.
class TomCupertinoButton extends TomButtonBase {
  final VoidCallback? onPressed;
  final Widget? child;
  final String? label;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color disabledColor;
  // ignore: deprecated_member_use - minSize is deprecated but minimumSize requires Size? not double?
  final double? minSize;
  final double? pressedOpacity;
  final BorderRadius? borderRadius;
  final AlignmentGeometry alignment;
  final bool filled;

  // Pre-resolved resource values
  late final String _resolvedLabel;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final Color? _resolvedColor;
  late final double? _resolvedMinSize;
  late final double? _resolvedPressedOpacity;

  TomCupertinoButton({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    VoidCallback? onPressed,
    this.child,
    this.label,
    this.padding,
    this.color,
    this.disabledColor = CupertinoColors.quaternarySystemFill,
    this.minSize = kMinInteractiveDimensionCupertino,
    this.pressedOpacity = 0.4,
    this.borderRadius = const BorderRadius.all(Radius.circular(8.0)),
    this.alignment = Alignment.center,
    this.filled = false,
  })  : onPressed = InScopeBuilder(scope: scope).wrap0n(onPressed) {
    _resolvedLabel = label ?? TomCtr.textOrFail(basePath, 'label', supersededBy: child);
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
    _resolvedMinSize = minSize ?? TomCtr.doubleVal(basePath, 'minSize');
    _resolvedPressedOpacity = pressedOpacity ?? TomCtr.doubleVal(basePath, 'pressedOpacity');
  }

  @override
  Widget buildContent(BuildContext context) {
    final buttonChild = child ?? Text(_resolvedLabel);

    if (filled) {
      return CupertinoButton.filled(
        onPressed: onPressed,
        padding: _resolvedPadding,
        disabledColor: disabledColor,
        // ignore: deprecated_member_use
        minSize: _resolvedMinSize,
        pressedOpacity: _resolvedPressedOpacity,
        borderRadius: borderRadius,
        alignment: alignment,
        child: buttonChild,
      );
    }

    return CupertinoButton(
      onPressed: onPressed,
      padding: _resolvedPadding,
      color: _resolvedColor,
      disabledColor: disabledColor,
      // ignore: deprecated_member_use
      minSize: _resolvedMinSize,
      pressedOpacity: _resolvedPressedOpacity,
      borderRadius: borderRadius,
      alignment: alignment,
      child: buttonChild,
    );
  }
}

/// Tom wrapper for [CheckboxMenuButton].
///
/// Menu item with checkbox toggle. Auth controls which menu options are visible.
class TomCheckboxMenuButton extends TomButtonBase {
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final bool tristate;
  final bool isError;
  final VoidCallback? onHover;
  final VoidCallback? onFocusChange;
  final FocusNode? focusNode;
  final MenuSerializableShortcut? shortcut;
  final Widget? child;
  final String? label;

  // Pre-resolved resource values
  late final String _resolvedLabel;

  TomCheckboxMenuButton({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    this.value,
    ValueChanged<bool?>? onChanged,
    this.tristate = false,
    this.isError = false,
    VoidCallback? onHover,
    VoidCallback? onFocusChange,
    this.focusNode,
    this.shortcut,
    this.child,
    this.label,
  })  : onChanged = InScopeBuilder(scope: scope).wrap1n(onChanged),
        onHover = InScopeBuilder(scope: scope).wrap0n(onHover),
        onFocusChange = InScopeBuilder(scope: scope).wrap0n(onFocusChange) {
    _resolvedLabel = label ?? TomCtr.textOrFail(basePath, 'label', supersededBy: child);
  }

  @override
  Widget buildContent(BuildContext context) {
    final buttonChild = child ?? Text(_resolvedLabel);

    return CheckboxMenuButton(
      value: value,
      onChanged: onChanged,
      tristate: tristate,
      isError: isError,
      focusNode: focusNode,
      shortcut: shortcut,
      child: buttonChild,
    );
  }
}

/// Tom wrapper for [RadioMenuButton].
///
/// Menu item with radio selection. Auth controls which menu options are visible.
class TomRadioMenuButton<T> extends TomButtonBase {
  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final bool toggleable;
  final VoidCallback? onHover;
  final VoidCallback? onFocusChange;
  final FocusNode? focusNode;
  final MenuSerializableShortcut? shortcut;
  final Widget? child;
  final String? label;

  // Pre-resolved resource values
  late final String _resolvedLabel;

  TomRadioMenuButton({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required this.value,
    this.groupValue,
    ValueChanged<T?>? onChanged,
    this.toggleable = false,
    VoidCallback? onHover,
    VoidCallback? onFocusChange,
    this.focusNode,
    this.shortcut,
    this.child,
    this.label,
  })  : onChanged = InScopeBuilder(scope: scope).wrap1n(onChanged),
        onHover = InScopeBuilder(scope: scope).wrap0n(onHover),
        onFocusChange = InScopeBuilder(scope: scope).wrap0n(onFocusChange) {
    _resolvedLabel = label ?? TomCtr.textOrFail(basePath, 'label', supersededBy: child);
  }

  @override
  Widget buildContent(BuildContext context) {
    final buttonChild = child ?? Text(_resolvedLabel);

    return RadioMenuButton<T>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      toggleable: toggleable,
      focusNode: focusNode,
      shortcut: shortcut,
      child: buttonChild,
    );
  }
}

/// Tom wrapper for [MenuBar].
///
/// Top-level menu bar container. Auth can hide entire menu bar sections.
class TomMenuBar extends TomButtonBase {
  final List<Widget> children;
  final MenuStyle? style;
  final Clip clipBehavior;

  TomMenuBar({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required this.children,
    this.style,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget buildContent(BuildContext context) {
    return MenuBar(
      style: style,
      clipBehavior: clipBehavior,
      children: children,
    );
  }
}

/// Tom wrapper for [CupertinoActionSheetAction].
///
/// Individual action inside CupertinoActionSheet. Per-action auth support.
class TomCupertinoActionSheetAction extends TomButtonBase {
  final VoidCallback onPressed;
  final bool isDefaultAction;
  final bool isDestructiveAction;
  final Widget child;

  TomCupertinoActionSheetAction({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required VoidCallback onPressed,
    this.isDefaultAction = false,
    this.isDestructiveAction = false,
    required this.child,
  })  : onPressed = InScopeBuilder(scope: scope).wrap0(onPressed);

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoActionSheetAction(
      onPressed: onPressed,
      isDefaultAction: isDefaultAction,
      isDestructiveAction: isDestructiveAction,
      child: child,
    );
  }
}

/// Tom wrapper for [CupertinoDialogAction].
///
/// Individual button inside CupertinoAlertDialog. Per-action auth support.
class TomCupertinoDialogAction extends TomButtonBase {
  final VoidCallback? onPressed;
  final bool isDefaultAction;
  final bool isDestructiveAction;
  final TextStyle? textStyle;
  final Widget child;

  // Pre-resolved resource values
  late final TextStyle? _resolvedTextStyle;

  TomCupertinoDialogAction({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    VoidCallback? onPressed,
    this.isDefaultAction = false,
    this.isDestructiveAction = false,
    this.textStyle,
    required this.child,
  })  : onPressed = InScopeBuilder(scope: scope).wrap0n(onPressed) {
    _resolvedTextStyle = textStyle ?? _resolveTextStyle('textStyle');
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoDialogAction(
      onPressed: onPressed,
      isDefaultAction: isDefaultAction,
      isDestructiveAction: isDestructiveAction,
      textStyle: _resolvedTextStyle,
      child: child,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }
}

/// Tom wrapper for [CupertinoContextMenuAction].
///
/// Individual action inside CupertinoContextMenu. Per-action auth support.
class TomCupertinoContextMenuAction extends TomButtonBase {
  final VoidCallback? onPressed;
  final bool isDefaultAction;
  final bool isDestructiveAction;
  final IconData? trailingIcon;
  final Widget child;

  TomCupertinoContextMenuAction({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    VoidCallback? onPressed,
    this.isDefaultAction = false,
    this.isDestructiveAction = false,
    this.trailingIcon,
    required this.child,
  })  : onPressed = InScopeBuilder(scope: scope).wrap0n(onPressed);

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoContextMenuAction(
      onPressed: onPressed,
      isDefaultAction: isDefaultAction,
      isDestructiveAction: isDestructiveAction,
      trailingIcon: trailingIcon,
      child: child,
    );
  }
}

/// Tom wrapper for [ExpandIcon].
///
/// Animated expand/collapse chevron. Auth can hide expand capability.
class TomExpandIcon extends TomButtonBase {
  final bool isExpanded;
  final ValueChanged<bool>? onPressed;
  final double? size;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? disabledColor;
  final Color? expandedColor;
  final String? semanticLabel;

  // Pre-resolved resource values
  late final double _resolvedSize;
  late final Color? _resolvedColor;
  late final Color? _resolvedDisabledColor;
  late final Color? _resolvedExpandedColor;

  TomExpandIcon({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    this.isExpanded = false,
    ValueChanged<bool>? onPressed,
    this.size,
    this.padding = const EdgeInsets.all(8.0),
    this.color,
    this.disabledColor,
    this.expandedColor,
    this.semanticLabel,
  })  : onPressed = InScopeBuilder(scope: scope).wrap1n(onPressed) {
    _resolvedSize = size ?? TomCtr.doubleVal(basePath, 'size') ?? 24.0;
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
    _resolvedDisabledColor = disabledColor ?? TomCtr.color(basePath, 'disabledColor');
    _resolvedExpandedColor = expandedColor ?? TomCtr.color(basePath, 'expandedColor');
  }

  @override
  Widget buildContent(BuildContext context) {
    // Note: ExpandIcon doesn't have a semanticLabel parameter in Flutter's API
    // The widget's semantics are handled internally via Semantics wrapper

    return ExpandIcon(
      isExpanded: isExpanded,
      onPressed: onPressed,
      size: _resolvedSize,
      padding: padding,
      color: _resolvedColor,
      disabledColor: _resolvedDisabledColor,
      expandedColor: _resolvedExpandedColor,
    );
  }
}

// ============================================================================
// EXTENSION-BASED WIDGETS (extends Flutter widget + TomWidgetMixin)
// ============================================================================

/// Tom wrapper for [SnackBarAction] with construction-time resource resolution.
///
/// Extends [SnackBarAction] directly to fit in `SnackBar(action:)`.
///
/// This is the one Tom wrapper with no widget slot to gate: [label] is a
/// `String`, not a child. [SnackBarAction]'s `State` is private, so
/// `super.build` is out of reach too. It resolves the impasse by supplying its
/// own `State`, which builds a plain [SnackBarAction] as a delegate and wraps
/// *that* — which works because [SnackBar] reads this widget only for
/// `label`'s width before mounting it as an ordinary child.
///
/// Resources are resolved at construction time:
/// - [label] — if null, resolved from `$tomId.label`
/// - [textColor] — resolved from `$tomId.textColor`
/// - [disabledTextColor] — resolved from `$tomId.disabledTextColor`
///
/// ```dart
/// TomSnackBar(
///   tomId: 'saveSuccess',
///   action: TomSnackBarAction(
///     tomId: 'undo',  // Resolves label from resources
///     onPressed: () => handleUndo(),
///   ),
/// )
/// ```
class TomSnackBarAction extends SnackBarAction with TomWidgetMixin {
  /// Tom ID for resource resolution.
  @override
  final String? tomId;

  /// Optional group membership.
  @override
  final TomAuthorizationGroup? tomGroup;

  /// Optional explicit scope for resource resolution.
  @override
  final TomScope? scope;

  /// Optional per-widget authorizer, applied after the group's mode.
  @override
  final TomAuthorizer? authorizer;

  /// Optional build-time UI-state controller, applied last.
  @override
  final TomUIStateController? uiStateController;

  /// Creates a Tom SnackBarAction with optional resource resolution.
  ///
  /// If [label] is null and [tomId] is provided, resolves the label from
  /// resources at `$tomId.label`.
  TomSnackBarAction({
    super.key,
    this.tomId,
    this.tomGroup,
    this.scope,
    this.authorizer,
    this.uiStateController,
    Color? textColor,
    Color? disabledTextColor,
    String? label,
    required VoidCallback onPressed,
  }) : super(
          onPressed: InScopeBuilder(scope: scope).wrap0(onPressed),
          label: label ?? TomCtr.text(_p(tomId, scope, 'label')),
          textColor: textColor ?? TomCtr.color(_p(tomId, scope, 'textColor')),
          disabledTextColor: disabledTextColor ?? TomCtr.color(_p(tomId, scope, 'disabledTextColor')),
        );

  /// Helper to build full path with suffix.
  static String? _p(String? tomId, TomScope? scope, String suffix) {
    final base = TomCtr.resolvePath(tomId, scope);
    return base != null ? '$base.$suffix' : null;
  }

  @override
  State<SnackBarAction> createState() => _TomSnackBarActionState();
}

class _TomSnackBarActionState extends State<TomSnackBarAction> {
  @override
  void initState() {
    super.initState();
    widget.registerWithGroup();
  }

  @override
  void dispose() {
    widget.unregisterFromGroup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hidden = widget.checkHidden();
    if (hidden != null) return hidden;
    return widget.applyAuthState(
      context,
      SnackBarAction(
        label: widget.label,
        onPressed: widget.onPressed,
        textColor: widget.textColor,
        disabledTextColor: widget.disabledTextColor,
        backgroundColor: widget.backgroundColor,
        disabledBackgroundColor: widget.disabledBackgroundColor,
      ),
    );
  }
}
