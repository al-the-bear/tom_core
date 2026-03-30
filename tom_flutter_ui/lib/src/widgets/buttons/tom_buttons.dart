import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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

  const TomElevatedButton({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onPressed,
    this.onLongPress,
    this.onHover,
    this.onFocusChange,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.icon,
    this.child,
    this.label,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = label ?? resolveResourceOrFail(context, 'label');
    final buttonChild = child ?? Text(resolvedLabel);

    // Resolve icon: use provided widget, or resolve from resources
    final resolvedIcon = icon ?? _buildResolvedIcon(context);

    // Phase 3: Resolve ButtonStyle from resources
    final resolvedStyle = style ?? _resolveStyle(context);

    if (resolvedIcon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        onLongPress: onLongPress,
        onHover: onHover,
        onFocusChange: onFocusChange,
        style: resolvedStyle,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        icon: resolvedIcon,
        label: buttonChild,
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: resolvedStyle,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      child: buttonChild,
    );
  }

  /// Builds an Icon widget from resolved icon data, or null if not available.
  Widget? _buildResolvedIcon(BuildContext context) {
    final iconData = resolveIcon(context);
    if (iconData == null) return null;
    return Icon(iconData);
  }

  /// Phase 3: Resolves ButtonStyle from resources.
  ButtonStyle? _resolveStyle(BuildContext context) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveButtonStyle(basePath, 'style');
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

  const TomTextButton({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onPressed,
    this.onLongPress,
    this.onHover,
    this.onFocusChange,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.icon,
    this.child,
    this.label,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = label ?? resolveResourceOrFail(context, 'label');
    final buttonChild = child ?? Text(resolvedLabel);
    final resolvedIcon = icon ?? _buildResolvedIcon(context);

    // Phase 3: Resolve ButtonStyle from resources
    final resolvedStyle = style ?? _resolveStyle(context);

    if (resolvedIcon != null) {
      return TextButton.icon(
        onPressed: onPressed,
        onLongPress: onLongPress,
        onHover: onHover,
        onFocusChange: onFocusChange,
        style: resolvedStyle,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        icon: resolvedIcon,
        label: buttonChild,
      );
    }

    return TextButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: resolvedStyle,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      child: buttonChild,
    );
  }

  Widget? _buildResolvedIcon(BuildContext context) {
    final iconData = resolveIcon(context);
    if (iconData == null) return null;
    return Icon(iconData);
  }

  /// Phase 3: Resolves ButtonStyle from resources.
  ButtonStyle? _resolveStyle(BuildContext context) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveButtonStyle(basePath, 'style');
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

  const TomOutlinedButton({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onPressed,
    this.onLongPress,
    this.onHover,
    this.onFocusChange,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.icon,
    this.child,
    this.label,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = label ?? resolveResourceOrFail(context, 'label');
    final buttonChild = child ?? Text(resolvedLabel);
    final resolvedIcon = icon ?? _buildResolvedIcon(context);

    // Phase 3: Resolve ButtonStyle from resources
    final resolvedStyle = style ?? _resolveStyle(context);

    if (resolvedIcon != null) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        onLongPress: onLongPress,
        onHover: onHover,
        onFocusChange: onFocusChange,
        style: resolvedStyle,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        icon: resolvedIcon,
        label: buttonChild,
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: resolvedStyle,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      child: buttonChild,
    );
  }

  Widget? _buildResolvedIcon(BuildContext context) {
    final iconData = resolveIcon(context);
    if (iconData == null) return null;
    return Icon(iconData);
  }

  /// Phase 3: Resolves ButtonStyle from resources.
  ButtonStyle? _resolveStyle(BuildContext context) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveButtonStyle(basePath, 'style');
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

  const TomFilledButton({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onPressed,
    this.onLongPress,
    this.onHover,
    this.onFocusChange,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.icon,
    this.child,
    this.label,
    this.tonal = false,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = label ?? resolveResourceOrFail(context, 'label');
    final buttonChild = child ?? Text(resolvedLabel);
    final resolvedIcon = icon ?? _buildResolvedIcon(context);

    // Phase 3: Resolve ButtonStyle from resources
    final resolvedStyle = style ?? _resolveStyle(context);

    if (tonal) {
      if (resolvedIcon != null) {
        return FilledButton.tonalIcon(
          onPressed: onPressed,
          onLongPress: onLongPress,
          onHover: onHover,
          onFocusChange: onFocusChange,
          style: resolvedStyle,
          focusNode: focusNode,
          autofocus: autofocus,
          clipBehavior: clipBehavior,
          icon: resolvedIcon,
          label: buttonChild,
        );
      }
      return FilledButton.tonal(
        onPressed: onPressed,
        onLongPress: onLongPress,
        onHover: onHover,
        onFocusChange: onFocusChange,
        style: resolvedStyle,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        child: buttonChild,
      );
    }

    if (resolvedIcon != null) {
      return FilledButton.icon(
        onPressed: onPressed,
        onLongPress: onLongPress,
        onHover: onHover,
        onFocusChange: onFocusChange,
        style: resolvedStyle,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        icon: resolvedIcon,
        label: buttonChild,
      );
    }

    return FilledButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: resolvedStyle,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      child: buttonChild,
    );
  }

  Widget? _buildResolvedIcon(BuildContext context) {
    final iconData = resolveIcon(context);
    if (iconData == null) return null;
    return Icon(iconData);
  }

  /// Phase 3: Resolves ButtonStyle from resources.
  ButtonStyle? _resolveStyle(BuildContext context) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveButtonStyle(basePath, 'style');
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

  const TomFloatingActionButton({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onPressed,
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
  })  : _variant = _FABVariant.regular,
        extendedIconLabelChild = null;

  /// Creates a small floating action button.
  const TomFloatingActionButton.small({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onPressed,
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
  })  : _variant = _FABVariant.small,
        isExtended = null,
        mini = false,
        icon = null,
        label = null,
        extendedIconLabelChild = null;

  /// Creates a large floating action button.
  const TomFloatingActionButton.large({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onPressed,
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
  })  : _variant = _FABVariant.large,
        isExtended = null,
        mini = false,
        icon = null,
        label = null,
        extendedIconLabelChild = null;

  /// Creates an extended floating action button with icon and label.
  const TomFloatingActionButton.extended({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onPressed,
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
  })  : _variant = _FABVariant.extended,
        child = null,
        mini = false;

  /// Resolves the child widget from parameter or resources.
  Widget? _resolveChild(BuildContext context) {
    if (child != null) return child;
    final iconData = resolveIcon(context);
    if (iconData != null) return Icon(iconData);
    return null;
  }

  /// Resolves the icon widget from parameter or resources.
  Widget? _resolveIconWidget(BuildContext context) {
    if (icon != null) return icon;
    final iconData = resolveIcon(context);
    if (iconData != null) return Icon(iconData);
    return null;
  }

  @override
  Widget buildContent(BuildContext context) {
    // Tooltip is always optional
    final resolvedTooltip = tooltip ?? resolveResourceOrNull(context, 'tooltip');

    // Phase 2: Resolve optional parameters from resources
    final resolvedForegroundColor =
        foregroundColor ?? resolveColorOrNull(context, 'foregroundColor');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull(context, 'backgroundColor');
    final resolvedFocusColor =
        focusColor ?? resolveColorOrNull(context, 'focusColor');
    final resolvedHoverColor =
        hoverColor ?? resolveColorOrNull(context, 'hoverColor');
    final resolvedSplashColor =
        splashColor ?? resolveColorOrNull(context, 'splashColor');
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull(context, 'elevation');
    final resolvedFocusElevation =
        focusElevation ?? resolveDoubleOrNull(context, 'focusElevation');
    final resolvedHoverElevation =
        hoverElevation ?? resolveDoubleOrNull(context, 'hoverElevation');
    final resolvedHighlightElevation =
        highlightElevation ?? resolveDoubleOrNull(context, 'highlightElevation');
    final resolvedDisabledElevation =
        disabledElevation ?? resolveDoubleOrNull(context, 'disabledElevation');
    final resolvedShape = shape ?? _resolveShapeBorder(context, 'shape');
    final resolvedAutofocus =
        resolveBoolOrNull(context, 'autofocus') ?? autofocus;
    final resolvedMini = resolveBoolOrNull(context, 'mini') ?? mini;
    final resolvedIsExtended = isExtended ?? resolveBoolOrNull(context, 'isExtended');

    switch (_variant) {
      case _FABVariant.extended:
        // Extended FAB requires a label
        final resolvedLabel = label ?? resolveResourceOrFail(context, 'label');
        return FloatingActionButton.extended(
          onPressed: onPressed,
          tooltip: resolvedTooltip,
          foregroundColor: resolvedForegroundColor,
          backgroundColor: resolvedBackgroundColor,
          focusColor: resolvedFocusColor,
          hoverColor: resolvedHoverColor,
          splashColor: resolvedSplashColor,
          heroTag: heroTag,
          elevation: resolvedElevation,
          focusElevation: resolvedFocusElevation,
          hoverElevation: resolvedHoverElevation,
          highlightElevation: resolvedHighlightElevation,
          disabledElevation: resolvedDisabledElevation,
          shape: resolvedShape,
          clipBehavior: clipBehavior,
          autofocus: resolvedAutofocus,
          focusNode: focusNode,
          isExtended: resolvedIsExtended ?? true,
          icon: _resolveIconWidget(context),
          label: extendedIconLabelChild ?? Text(resolvedLabel),
        );

      case _FABVariant.small:
        return FloatingActionButton.small(
          onPressed: onPressed,
          tooltip: resolvedTooltip,
          foregroundColor: resolvedForegroundColor,
          backgroundColor: resolvedBackgroundColor,
          focusColor: resolvedFocusColor,
          hoverColor: resolvedHoverColor,
          splashColor: resolvedSplashColor,
          heroTag: heroTag,
          elevation: resolvedElevation,
          focusElevation: resolvedFocusElevation,
          hoverElevation: resolvedHoverElevation,
          highlightElevation: resolvedHighlightElevation,
          disabledElevation: resolvedDisabledElevation,
          shape: resolvedShape,
          clipBehavior: clipBehavior,
          autofocus: resolvedAutofocus,
          focusNode: focusNode,
          child: _resolveChild(context),
        );

      case _FABVariant.large:
        return FloatingActionButton.large(
          onPressed: onPressed,
          tooltip: resolvedTooltip,
          foregroundColor: resolvedForegroundColor,
          backgroundColor: resolvedBackgroundColor,
          focusColor: resolvedFocusColor,
          hoverColor: resolvedHoverColor,
          splashColor: resolvedSplashColor,
          heroTag: heroTag,
          elevation: resolvedElevation,
          focusElevation: resolvedFocusElevation,
          hoverElevation: resolvedHoverElevation,
          highlightElevation: resolvedHighlightElevation,
          disabledElevation: resolvedDisabledElevation,
          shape: resolvedShape,
          clipBehavior: clipBehavior,
          autofocus: resolvedAutofocus,
          focusNode: focusNode,
          child: _resolveChild(context),
        );

      case _FABVariant.regular:
        final resolvedIcon = _resolveIconWidget(context);
        final resolvedLabel = label ?? resolveResourceOrNull(context, 'label');
        // Legacy behavior: if icon and label are both provided, use extended
        if (resolvedIcon != null && resolvedLabel != null) {
          return FloatingActionButton.extended(
            onPressed: onPressed,
            tooltip: resolvedTooltip,
            foregroundColor: resolvedForegroundColor,
            backgroundColor: resolvedBackgroundColor,
            focusColor: resolvedFocusColor,
            hoverColor: resolvedHoverColor,
            splashColor: resolvedSplashColor,
            heroTag: heroTag,
            elevation: resolvedElevation,
            focusElevation: resolvedFocusElevation,
            hoverElevation: resolvedHoverElevation,
            highlightElevation: resolvedHighlightElevation,
            disabledElevation: resolvedDisabledElevation,
            shape: resolvedShape,
            clipBehavior: clipBehavior,
            autofocus: resolvedAutofocus,
            focusNode: focusNode,
            isExtended: resolvedIsExtended ?? true,
            icon: resolvedIcon,
            label: Text(resolvedLabel),
          );
        }

        // Legacy behavior: if mini is true, use small
        if (resolvedMini) {
          return FloatingActionButton.small(
            onPressed: onPressed,
            tooltip: resolvedTooltip,
            foregroundColor: resolvedForegroundColor,
            backgroundColor: resolvedBackgroundColor,
            focusColor: resolvedFocusColor,
            hoverColor: resolvedHoverColor,
            splashColor: resolvedSplashColor,
            heroTag: heroTag,
            elevation: resolvedElevation,
            focusElevation: resolvedFocusElevation,
            hoverElevation: resolvedHoverElevation,
            highlightElevation: resolvedHighlightElevation,
            disabledElevation: resolvedDisabledElevation,
            shape: resolvedShape,
            clipBehavior: clipBehavior,
            autofocus: resolvedAutofocus,
            focusNode: focusNode,
            child: _resolveChild(context),
          );
        }

        return FloatingActionButton(
          onPressed: onPressed,
          tooltip: resolvedTooltip,
          foregroundColor: resolvedForegroundColor,
          backgroundColor: resolvedBackgroundColor,
          focusColor: resolvedFocusColor,
          hoverColor: resolvedHoverColor,
          splashColor: resolvedSplashColor,
          heroTag: heroTag,
          elevation: resolvedElevation,
          focusElevation: resolvedFocusElevation,
          hoverElevation: resolvedHoverElevation,
          highlightElevation: resolvedHighlightElevation,
          disabledElevation: resolvedDisabledElevation,
          shape: resolvedShape,
          clipBehavior: clipBehavior,
          autofocus: resolvedAutofocus,
          focusNode: focusNode,
          mini: resolvedMini,
          child: _resolveChild(context),
        );
    }
  }

  ShapeBorder? _resolveShapeBorder(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath, suffix);
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

  const TomMenuItemButton({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onPressed,
    this.onHover,
    this.onFocusChange,
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
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = label ?? resolveResourceOrFail(context, 'label');
    final buttonChild = child ?? Text(resolvedLabel);

    // Phase 3: Resolve ButtonStyle from resources
    final resolvedStyle = style ?? _resolveStyle(context);

    return MenuItemButton(
      onPressed: onPressed,
      focusNode: focusNode,
      shortcut: shortcut,
      style: resolvedStyle,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      closeOnActivate: closeOnActivate,
      child: buttonChild,
    );
  }

  /// Phase 3: Resolves ButtonStyle from resources.
  ButtonStyle? _resolveStyle(BuildContext context) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveButtonStyle(basePath, 'style');
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

  const TomSubmenuButton({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onOpen,
    this.onClose,
    this.onHover,
    this.onFocusChange,
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
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = label ?? resolveResourceOrFail(context, 'label');
    final buttonChild = child ?? Text(resolvedLabel);

    // Phase 3: Resolve ButtonStyle and MenuStyle from resources
    final resolvedStyle = style ?? _resolveStyle(context);
    final resolvedMenuStyle = menuStyle ?? _resolveMenuStyle(context);
    final resolvedAlignmentOffset =
        alignmentOffset ?? _resolveOffset(context, 'alignmentOffset');

    return SubmenuButton(
      onOpen: onOpen,
      onClose: onClose,
      focusNode: focusNode,
      style: resolvedStyle,
      menuStyle: resolvedMenuStyle,
      alignmentOffset: resolvedAlignmentOffset,
      clipBehavior: clipBehavior,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      menuChildren: menuChildren,
      child: buttonChild,
    );
  }

  /// Phase 3: Resolves ButtonStyle from resources.
  ButtonStyle? _resolveStyle(BuildContext context) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveButtonStyle(basePath, 'style');
  }

  /// Phase 3: Resolves MenuStyle from resources.
  MenuStyle? _resolveMenuStyle(BuildContext context) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveMenuStyle(basePath, 'menuStyle');
  }

  /// Phase 3: Resolves Offset from resources.
  Offset? _resolveOffset(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveOffset(basePath, suffix);
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

  const TomSegmentedButton({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.segments,
    required this.selected,
    this.onSelectionChanged,
    this.multiSelectionEnabled = false,
    this.emptySelectionAllowed = false,
    this.style,
    this.showSelectedIcon = true,
    this.selectedIcon,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 3: Resolve ButtonStyle from resources
    final resolvedStyle = style ?? _resolveStyle(context);

    return SegmentedButton<T>(
      segments: segments,
      selected: selected,
      onSelectionChanged: onSelectionChanged,
      multiSelectionEnabled: multiSelectionEnabled,
      emptySelectionAllowed: emptySelectionAllowed,
      style: resolvedStyle,
      showSelectedIcon: showSelectedIcon,
      selectedIcon: selectedIcon,
    );
  }

  /// Phase 3: Resolves ButtonStyle from resources.
  ButtonStyle? _resolveStyle(BuildContext context) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveButtonStyle(basePath, 'style');
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

  const TomIconButton({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onPressed,
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
  }) : _variant = _IconButtonVariant.regular;

  /// Creates a filled icon button.
  const TomIconButton.filled({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onPressed,
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
  }) : _variant = _IconButtonVariant.filled;

  /// Creates a filled tonal icon button.
  const TomIconButton.filledTonal({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onPressed,
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
  }) : _variant = _IconButtonVariant.filledTonal;

  /// Creates an outlined icon button.
  const TomIconButton.outlined({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onPressed,
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
  }) : _variant = _IconButtonVariant.outlined;

  /// Resolves the icon widget from parameter or resources.
  Widget _resolveIcon(BuildContext context) {
    if (icon != null) return icon!;
    final iconData = resolveIcon(context);
    if (iconData != null) return Icon(iconData);
    // Fallback to placeholder icon
    return const Icon(Icons.error_outline);
  }

  @override
  Widget buildContent(BuildContext context) {
    final resolvedTooltip = tooltip ?? resolveResourceOrFail(context, 'tooltip');
    final resolvedIcon = _resolveIcon(context);

    // Phase 2: Resolve optional parameters from resources
    final resolvedIconSize = iconSize ?? resolveDoubleOrNull(context, 'iconSize');
    final resolvedSplashRadius =
        splashRadius ?? resolveDoubleOrNull(context, 'splashRadius');
    final resolvedColor = color ?? resolveColorOrNull(context, 'color');
    final resolvedFocusColor =
        focusColor ?? resolveColorOrNull(context, 'focusColor');
    final resolvedHoverColor =
        hoverColor ?? resolveColorOrNull(context, 'hoverColor');
    final resolvedHighlightColor =
        highlightColor ?? resolveColorOrNull(context, 'highlightColor');
    final resolvedSplashColor =
        splashColor ?? resolveColorOrNull(context, 'splashColor');
    final resolvedDisabledColor =
        disabledColor ?? resolveColorOrNull(context, 'disabledColor');
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull(context, 'padding');
    final resolvedAlignment =
        alignment ?? _resolveAlignment(context, 'alignment') ?? Alignment.center;
    final resolvedConstraints =
        constraints ?? _resolveBoxConstraints(context, 'constraints');

    // Phase 3: Resolve ButtonStyle from resources
    final resolvedStyle = style ?? _resolveStyle(context);

    switch (_variant) {
      case _IconButtonVariant.filled:
        return IconButton.filled(
          onPressed: onPressed,
          iconSize: resolvedIconSize,
          visualDensity: visualDensity,
          padding: resolvedPadding,
          alignment: resolvedAlignment,
          splashRadius: resolvedSplashRadius,
          color: resolvedColor,
          focusColor: resolvedFocusColor,
          hoverColor: resolvedHoverColor,
          highlightColor: resolvedHighlightColor,
          splashColor: resolvedSplashColor,
          disabledColor: resolvedDisabledColor,
          autofocus: autofocus,
          constraints: resolvedConstraints,
          style: resolvedStyle,
          isSelected: isSelected,
          selectedIcon: selectedIcon,
          icon: resolvedIcon,
          tooltip: resolvedTooltip,
          focusNode: focusNode,
        );

      case _IconButtonVariant.filledTonal:
        return IconButton.filledTonal(
          onPressed: onPressed,
          iconSize: resolvedIconSize,
          visualDensity: visualDensity,
          padding: resolvedPadding,
          alignment: resolvedAlignment,
          splashRadius: resolvedSplashRadius,
          color: resolvedColor,
          focusColor: resolvedFocusColor,
          hoverColor: resolvedHoverColor,
          highlightColor: resolvedHighlightColor,
          splashColor: resolvedSplashColor,
          disabledColor: resolvedDisabledColor,
          autofocus: autofocus,
          constraints: resolvedConstraints,
          style: resolvedStyle,
          isSelected: isSelected,
          selectedIcon: selectedIcon,
          icon: resolvedIcon,
          tooltip: resolvedTooltip,
          focusNode: focusNode,
        );

      case _IconButtonVariant.outlined:
        return IconButton.outlined(
          onPressed: onPressed,
          iconSize: resolvedIconSize,
          visualDensity: visualDensity,
          padding: resolvedPadding,
          alignment: resolvedAlignment,
          splashRadius: resolvedSplashRadius,
          color: resolvedColor,
          focusColor: resolvedFocusColor,
          hoverColor: resolvedHoverColor,
          highlightColor: resolvedHighlightColor,
          splashColor: resolvedSplashColor,
          disabledColor: resolvedDisabledColor,
          autofocus: autofocus,
          constraints: resolvedConstraints,
          style: resolvedStyle,
          isSelected: isSelected,
          selectedIcon: selectedIcon,
          icon: resolvedIcon,
          tooltip: resolvedTooltip,
          focusNode: focusNode,
        );

      case _IconButtonVariant.regular:
        return IconButton(
          onPressed: onPressed,
          iconSize: resolvedIconSize,
          visualDensity: visualDensity,
          padding: resolvedPadding,
          alignment: resolvedAlignment,
          splashRadius: resolvedSplashRadius,
          color: resolvedColor,
          focusColor: resolvedFocusColor,
          hoverColor: resolvedHoverColor,
          highlightColor: resolvedHighlightColor,
          splashColor: resolvedSplashColor,
          disabledColor: resolvedDisabledColor,
          autofocus: autofocus,
          constraints: resolvedConstraints,
          style: resolvedStyle,
          isSelected: isSelected,
          selectedIcon: selectedIcon,
          icon: resolvedIcon,
          tooltip: resolvedTooltip,
          focusNode: focusNode,
        );
    }
  }

  /// Phase 3: Resolves ButtonStyle from resources.
  ButtonStyle? _resolveStyle(BuildContext context) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveButtonStyle(basePath, 'style');
  }

  /// Phase 2: Resolves AlignmentGeometry from resources.
  AlignmentGeometry? _resolveAlignment(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath, suffix);
  }

  /// Phase 2: Resolves BoxConstraints from resources.
  BoxConstraints? _resolveBoxConstraints(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBoxConstraints(basePath, suffix);
  }
}

/// Tom wrapper for [BackButton].
///
/// Adds ID, group, authorization, and resource resolution.
class TomBackButton extends TomButtonBase {
  final VoidCallback? onPressed;
  final Color? color;

  const TomBackButton({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onPressed,
    this.color,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve color from resources if not explicitly set
    final resolvedColor = color ?? resolveColorOrNull(context, 'color');
    return BackButton(
      onPressed: onPressed,
      color: resolvedColor,
    );
  }
}

/// Tom wrapper for [CloseButton].
///
/// Adds ID, group, authorization, and resource resolution.
class TomCloseButton extends TomButtonBase {
  final VoidCallback? onPressed;
  final Color? color;

  const TomCloseButton({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onPressed,
    this.color,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve color from resources if not explicitly set
    final resolvedColor = color ?? resolveColorOrNull(context, 'color');
    return CloseButton(
      onPressed: onPressed,
      color: resolvedColor,
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

  const TomDropdownMenuEntry({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.value,
    this.label,
    this.leadingIcon,
    this.trailingIcon,
    this.enabled = true,
    this.style,
    this.labelWidget,
  });

  /// Creates the underlying [DropdownMenuEntry] for use in a [DropdownMenu].
  DropdownMenuEntry<T> toEntry(BuildContext context) {
    final resolvedLabel = label ?? resolveResourceOrFail(context, 'label');

    // Phase 3: Resolve ButtonStyle from resources
    final resolvedStyle = style ?? _resolveStyle(context);

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
    final resolvedLabel = label ?? resolveResourceOrFail(context, 'label');

    return Text(resolvedLabel);
  }

  /// Phase 3: Resolves ButtonStyle from resources.
  ButtonStyle? _resolveStyle(BuildContext context) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveButtonStyle(basePath, 'style');
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

  const TomCupertinoButton({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onPressed,
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
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = label ?? resolveResourceOrFail(context, 'label');
    final buttonChild = child ?? Text(resolvedLabel);

    // Phase 2: Resolve optional parameters from resources
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull(context, 'padding');
    final resolvedColor = color ?? resolveColorOrNull(context, 'color');
    final resolvedMinSize =
        minSize ?? resolveDoubleOrNull(context, 'minSize');
    final resolvedPressedOpacity =
        pressedOpacity ?? resolveDoubleOrNull(context, 'pressedOpacity');

    if (filled) {
      return CupertinoButton.filled(
        onPressed: onPressed,
        padding: resolvedPadding,
        disabledColor: disabledColor,
        // ignore: deprecated_member_use
        minSize: resolvedMinSize,
        pressedOpacity: resolvedPressedOpacity,
        borderRadius: borderRadius,
        alignment: alignment,
        child: buttonChild,
      );
    }

    return CupertinoButton(
      onPressed: onPressed,
      padding: resolvedPadding,
      color: resolvedColor,
      disabledColor: disabledColor,
      // ignore: deprecated_member_use
      minSize: resolvedMinSize,
      pressedOpacity: resolvedPressedOpacity,
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

  const TomCheckboxMenuButton({
    super.key,
    super.tomId,
    super.tomGroup,
    this.value,
    this.onChanged,
    this.tristate = false,
    this.isError = false,
    this.onHover,
    this.onFocusChange,
    this.focusNode,
    this.shortcut,
    this.child,
    this.label,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = label ?? resolveResourceOrFail(context, 'label');
    final buttonChild = child ?? Text(resolvedLabel);

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

  const TomRadioMenuButton({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.value,
    this.groupValue,
    this.onChanged,
    this.toggleable = false,
    this.onHover,
    this.onFocusChange,
    this.focusNode,
    this.shortcut,
    this.child,
    this.label,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = label ?? resolveResourceOrFail(context, 'label');
    final buttonChild = child ?? Text(resolvedLabel);

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

  const TomMenuBar({
    super.key,
    super.tomId,
    super.tomGroup,
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

  const TomCupertinoActionSheetAction({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.onPressed,
    this.isDefaultAction = false,
    this.isDestructiveAction = false,
    required this.child,
  });

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

  const TomCupertinoDialogAction({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onPressed,
    this.isDefaultAction = false,
    this.isDestructiveAction = false,
    this.textStyle,
    required this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 3: Resolve optional TextStyle from resources
    final resolvedTextStyle = textStyle ?? _resolveTextStyle(context, 'textStyle');

    return CupertinoDialogAction(
      onPressed: onPressed,
      isDefaultAction: isDefaultAction,
      isDestructiveAction: isDestructiveAction,
      textStyle: resolvedTextStyle,
      child: child,
    );
  }

  TextStyle? _resolveTextStyle(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
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

  const TomCupertinoContextMenuAction({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onPressed,
    this.isDefaultAction = false,
    this.isDestructiveAction = false,
    this.trailingIcon,
    required this.child,
  });

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

  const TomExpandIcon({
    super.key,
    super.tomId,
    super.tomGroup,
    this.isExpanded = false,
    this.onPressed,
    this.size,
    this.padding = const EdgeInsets.all(8.0),
    this.color,
    this.disabledColor,
    this.expandedColor,
    this.semanticLabel,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedSize =
        size ?? resolveDoubleOrNull(context, 'size') ?? 24.0;
    final resolvedColor =
        color ?? resolveColorOrNull(context, 'color');
    final resolvedDisabledColor =
        disabledColor ?? resolveColorOrNull(context, 'disabledColor');
    final resolvedExpandedColor =
        expandedColor ?? resolveColorOrNull(context, 'expandedColor');
    // Note: ExpandIcon doesn't have a semanticLabel parameter in Flutter's API
    // The widget's semantics are handled internally via Semantics wrapper

    return ExpandIcon(
      isExpanded: isExpanded,
      onPressed: onPressed,
      size: resolvedSize,
      padding: padding,
      color: resolvedColor,
      disabledColor: resolvedDisabledColor,
      expandedColor: resolvedExpandedColor,
    );
  }
}

// ============================================================================
// DEPRECATED BUTTONS — Wrapped for migration support
// ============================================================================

/// Tom wrapper for [MaterialButton].
///
/// **Deprecated** — use TomElevatedButton, TomTextButton, or TomOutlinedButton.
/// Wrapped for migration of existing codebases.
@Deprecated('Use TomElevatedButton, TomTextButton, or TomOutlinedButton instead')
class TomMaterialButton extends TomButtonBase {
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onHighlightChanged;
  final MouseCursor? mouseCursor;
  final ButtonTextTheme? textTheme;
  final Color? textColor;
  final Color? disabledTextColor;
  final Color? color;
  final Color? disabledColor;
  final Color? focusColor;
  final Color? hoverColor;
  final Color? highlightColor;
  final Color? splashColor;
  final Brightness? colorBrightness;
  final double? elevation;
  final double? focusElevation;
  final double? hoverElevation;
  final double? highlightElevation;
  final double? disabledElevation;
  final EdgeInsetsGeometry? padding;
  final VisualDensity? visualDensity;
  final ShapeBorder? shape;
  final Clip clipBehavior;
  final FocusNode? focusNode;
  final bool autofocus;
  final Duration? animationDuration;
  final double? minWidth;
  final double? height;
  final bool enableFeedback;
  final Widget? child;
  final String? label;

  const TomMaterialButton({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onPressed,
    this.onLongPress,
    this.onHighlightChanged,
    this.mouseCursor,
    this.textTheme,
    this.textColor,
    this.disabledTextColor,
    this.color,
    this.disabledColor,
    this.focusColor,
    this.hoverColor,
    this.highlightColor,
    this.splashColor,
    this.colorBrightness,
    this.elevation,
    this.focusElevation,
    this.hoverElevation,
    this.highlightElevation,
    this.disabledElevation,
    this.padding,
    this.visualDensity,
    this.shape,
    this.clipBehavior = Clip.none,
    this.focusNode,
    this.autofocus = false,
    this.animationDuration,
    this.minWidth,
    this.height,
    this.enableFeedback = true,
    this.child,
    this.label,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = label ?? resolveResourceOrFail(context, 'label');
    final buttonChild = child ?? Text(resolvedLabel);

    // ignore: deprecated_member_use
    return MaterialButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHighlightChanged: onHighlightChanged,
      mouseCursor: mouseCursor,
      textTheme: textTheme,
      textColor: textColor ?? resolveColorOrNull(context, 'textColor'),
      disabledTextColor: disabledTextColor ?? resolveColorOrNull(context, 'disabledTextColor'),
      color: color ?? resolveColorOrNull(context, 'color'),
      disabledColor: disabledColor ?? resolveColorOrNull(context, 'disabledColor'),
      focusColor: focusColor ?? resolveColorOrNull(context, 'focusColor'),
      hoverColor: hoverColor ?? resolveColorOrNull(context, 'hoverColor'),
      highlightColor: highlightColor ?? resolveColorOrNull(context, 'highlightColor'),
      splashColor: splashColor ?? resolveColorOrNull(context, 'splashColor'),
      colorBrightness: colorBrightness,
      elevation: elevation ?? resolveDoubleOrNull(context, 'elevation'),
      focusElevation: focusElevation ?? resolveDoubleOrNull(context, 'focusElevation'),
      hoverElevation: hoverElevation ?? resolveDoubleOrNull(context, 'hoverElevation'),
      highlightElevation: highlightElevation ?? resolveDoubleOrNull(context, 'highlightElevation'),
      disabledElevation: disabledElevation ?? resolveDoubleOrNull(context, 'disabledElevation'),
      padding: padding ?? resolveEdgeInsetsOrNull(context, 'padding'),
      visualDensity: visualDensity,
      shape: shape ?? _resolveShapeBorder(context, 'shape'),
      clipBehavior: clipBehavior,
      focusNode: focusNode,
      autofocus: autofocus,
      animationDuration: animationDuration,
      minWidth: minWidth ?? resolveDoubleOrNull(context, 'minWidth'),
      height: height ?? resolveDoubleOrNull(context, 'height'),
      enableFeedback: enableFeedback,
      child: buttonChild,
    );
  }

  ShapeBorder? _resolveShapeBorder(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath, suffix);
  }
}

/// Tom wrapper for [ButtonBar].
///
/// **Deprecated** — use TomOverflowBar instead.
/// Wrapped for migration of existing codebases.
@Deprecated('Use TomOverflowBar instead')
class TomButtonBar extends TomButtonBase {
  final List<Widget> children;
  final MainAxisAlignment? alignment;
  final MainAxisSize? mainAxisSize;
  final ButtonTextTheme? buttonTextTheme;
  final double? buttonMinWidth;
  final double? buttonHeight;
  final EdgeInsetsGeometry? buttonPadding;
  final bool? buttonAlignedDropdown;
  final ButtonBarLayoutBehavior? layoutBehavior;
  final VerticalDirection? overflowDirection;
  final double? overflowButtonSpacing;

  const TomButtonBar({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.children,
    this.alignment,
    this.mainAxisSize,
    this.buttonTextTheme,
    this.buttonMinWidth,
    this.buttonHeight,
    this.buttonPadding,
    this.buttonAlignedDropdown,
    this.layoutBehavior,
    this.overflowDirection,
    this.overflowButtonSpacing,
  });

  @override
  Widget buildContent(BuildContext context) {
    // ignore: deprecated_member_use
    return ButtonBar(
      alignment: alignment,
      mainAxisSize: mainAxisSize,
      buttonTextTheme: buttonTextTheme,
      buttonMinWidth: buttonMinWidth ?? resolveDoubleOrNull(context, 'buttonMinWidth'),
      buttonHeight: buttonHeight ?? resolveDoubleOrNull(context, 'buttonHeight'),
      buttonPadding: buttonPadding ?? resolveEdgeInsetsOrNull(context, 'buttonPadding'),
      buttonAlignedDropdown: buttonAlignedDropdown,
      layoutBehavior: layoutBehavior,
      overflowDirection: overflowDirection,
      overflowButtonSpacing: overflowButtonSpacing ?? resolveDoubleOrNull(context, 'overflowButtonSpacing'),
      children: children,
    );
  }
}

// ============================================================================
// EXTENSION-BASED WIDGETS (extends Flutter widget + TomWidgetMixin)
// ============================================================================

/// Tom wrapper for [SnackBarAction] — fits in `SnackBar(action:)`.
///
/// ```dart
/// TomSnackBar(
///   content: Text('Message'),
///   action: TomSnackBarAction(label: 'Undo', onPressed: () {}),
/// )
/// ```
///
/// Note: No TomWidgetMixin — parameters are forwarded to super at
/// construction time (before BuildContext is available), so resource
/// resolution is structurally impossible.
class TomSnackBarAction extends SnackBarAction {
  /// Creates a Tom SnackBarAction.
  TomSnackBarAction({
    super.key,
    super.textColor,
    super.disabledTextColor,
    required super.label,
    required super.onPressed,
  });
}
