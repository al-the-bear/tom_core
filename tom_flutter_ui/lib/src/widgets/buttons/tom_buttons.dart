import 'package:flutter/material.dart';

import '../../widget_base/tom_family_base.dart';

/// Tom wrapper for [ElevatedButton].
///
/// Adds ID, group, authorization, and resource resolution to the standard
/// Flutter [ElevatedButton]. Exposes the full underlying API.
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
    final resolvedLabel = label ?? resolveResource(context, 'label');
    final buttonChild = child ?? Text(resolvedLabel);

    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        onLongPress: onLongPress,
        onHover: onHover,
        onFocusChange: onFocusChange,
        style: style,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        icon: icon!,
        label: buttonChild,
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      child: buttonChild,
    );
  }
}

/// Tom wrapper for [TextButton].
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
    final resolvedLabel = label ?? resolveResource(context, 'label');
    final buttonChild = child ?? Text(resolvedLabel);

    if (icon != null) {
      return TextButton.icon(
        onPressed: onPressed,
        onLongPress: onLongPress,
        onHover: onHover,
        onFocusChange: onFocusChange,
        style: style,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        icon: icon!,
        label: buttonChild,
      );
    }

    return TextButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      child: buttonChild,
    );
  }
}

/// Tom wrapper for [OutlinedButton].
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
    final resolvedLabel = label ?? resolveResource(context, 'label');
    final buttonChild = child ?? Text(resolvedLabel);

    if (icon != null) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        onLongPress: onLongPress,
        onHover: onHover,
        onFocusChange: onFocusChange,
        style: style,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        icon: icon!,
        label: buttonChild,
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      child: buttonChild,
    );
  }
}

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
  final Widget icon;
  final String? tooltip;
  final FocusNode? focusNode;

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
    required this.icon,
    this.tooltip,
    this.focusNode,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedTooltip = tooltip ?? (tomId != null ? resolveResource(context, 'tooltip') : null);

    return IconButton(
      onPressed: onPressed,
      iconSize: iconSize,
      visualDensity: visualDensity,
      padding: padding,
      alignment: alignment ?? Alignment.center,
      splashRadius: splashRadius,
      color: color,
      focusColor: focusColor,
      hoverColor: hoverColor,
      highlightColor: highlightColor,
      splashColor: splashColor,
      disabledColor: disabledColor,
      autofocus: autofocus,
      constraints: constraints,
      style: style,
      isSelected: isSelected,
      selectedIcon: selectedIcon,
      icon: icon,
      tooltip: resolvedTooltip,
      focusNode: focusNode,
    );
  }
}
