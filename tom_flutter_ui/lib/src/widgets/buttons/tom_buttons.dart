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

/// Tom wrapper for [FilledButton].
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
    final resolvedLabel = label ?? resolveResource(context, 'label');
    final buttonChild = child ?? Text(resolvedLabel);

    if (tonal) {
      if (icon != null) {
        return FilledButton.tonalIcon(
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
      return FilledButton.tonal(
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

    if (icon != null) {
      return FilledButton.icon(
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

    return FilledButton(
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
  final String? label;

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
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedTooltip =
        tooltip ?? (tomId != null ? resolveResource(context, 'tooltip') : null);

    if (icon != null && label != null) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        tooltip: resolvedTooltip,
        foregroundColor: foregroundColor,
        backgroundColor: backgroundColor,
        focusColor: focusColor,
        hoverColor: hoverColor,
        splashColor: splashColor,
        elevation: elevation,
        focusElevation: focusElevation,
        hoverElevation: hoverElevation,
        highlightElevation: highlightElevation,
        disabledElevation: disabledElevation,
        shape: shape,
        clipBehavior: clipBehavior,
        autofocus: autofocus,
        focusNode: focusNode,
        isExtended: isExtended ?? true,
        icon: icon,
        label: Text(label!),
      );
    }

    if (mini) {
      return FloatingActionButton.small(
        onPressed: onPressed,
        tooltip: resolvedTooltip,
        foregroundColor: foregroundColor,
        backgroundColor: backgroundColor,
        focusColor: focusColor,
        hoverColor: hoverColor,
        splashColor: splashColor,
        elevation: elevation,
        focusElevation: focusElevation,
        hoverElevation: hoverElevation,
        highlightElevation: highlightElevation,
        disabledElevation: disabledElevation,
        shape: shape,
        clipBehavior: clipBehavior,
        autofocus: autofocus,
        focusNode: focusNode,
        child: child,
      );
    }

    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: resolvedTooltip,
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
      focusColor: focusColor,
      hoverColor: hoverColor,
      splashColor: splashColor,
      elevation: elevation,
      focusElevation: focusElevation,
      hoverElevation: hoverElevation,
      highlightElevation: highlightElevation,
      disabledElevation: disabledElevation,
      shape: shape,
      clipBehavior: clipBehavior,
      autofocus: autofocus,
      focusNode: focusNode,
      mini: mini,
      child: child,
    );
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
    final resolvedLabel = label ?? resolveResource(context, 'label');
    final buttonChild = child ?? Text(resolvedLabel);

    return MenuItemButton(
      onPressed: onPressed,
      focusNode: focusNode,
      shortcut: shortcut,
      style: style,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      closeOnActivate: closeOnActivate,
      child: buttonChild,
    );
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
    final resolvedLabel = label ?? resolveResource(context, 'label');
    final buttonChild = child ?? Text(resolvedLabel);

    return SubmenuButton(
      onOpen: onOpen,
      onClose: onClose,
      focusNode: focusNode,
      style: style,
      menuStyle: menuStyle,
      alignmentOffset: alignmentOffset,
      clipBehavior: clipBehavior,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      menuChildren: menuChildren,
      child: buttonChild,
    );
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
    return SegmentedButton<T>(
      segments: segments,
      selected: selected,
      onSelectionChanged: onSelectionChanged,
      multiSelectionEnabled: multiSelectionEnabled,
      emptySelectionAllowed: emptySelectionAllowed,
      style: style,
      showSelectedIcon: showSelectedIcon,
      selectedIcon: selectedIcon,
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
