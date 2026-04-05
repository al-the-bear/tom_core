import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    hide
        showDialog,
        showModalBottomSheet,
        showDatePicker,
        showTimePicker,
        showDateRangePicker,
        showMenu,
        showSearch;
import 'package:flutter/material.dart' as material
    show
        showDialog,
        showModalBottomSheet,
        showDatePicker,
        showTimePicker,
        showDateRangePicker,
        showMenu,
        showSearch;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../groups/tom_ui_group.dart';
import '../../widget_base/tom_construction_helpers.dart';
import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_style_resolvers.dart';

/// Tom wrapper for [AlertDialog].
///
/// Adds ID, group, authorization, and resource resolution to the standard
/// Flutter [AlertDialog]. Exposes the full underlying API.
/// Adds ID, group, authorization, and resource resolution.
class TomAlertDialog extends TomDialogBase {
  final Widget? icon;
  final EdgeInsetsGeometry? iconPadding;
  final Color? iconColor;
  final Widget? title;
  final String? titleText;
  final EdgeInsetsGeometry? titlePadding;
  final TextStyle? titleTextStyle;
  final Widget? content;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? contentTextStyle;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? actionsPadding;
  final MainAxisAlignment? actionsAlignment;
  final OverflowBarAlignment? actionsOverflowAlignment;
  final VerticalDirection? actionsOverflowDirection;
  final double? actionsOverflowButtonSpacing;
  final EdgeInsetsGeometry? buttonPadding;
  final Color? backgroundColor;
  final double? elevation;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final String? semanticLabel;
  final EdgeInsets insetPadding;
  final Clip clipBehavior;
  final ShapeBorder? shape;
  final AlignmentGeometry? alignment;
  final bool scrollable;

  TomAlertDialog({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.icon,
    this.iconPadding,
    this.iconColor,
    this.title,
    this.titleText,
    this.titlePadding,
    this.titleTextStyle,
    this.content,
    this.contentPadding,
    this.contentTextStyle,
    this.actions,
    this.actionsPadding,
    this.actionsAlignment,
    this.actionsOverflowAlignment,
    this.actionsOverflowDirection,
    this.actionsOverflowButtonSpacing,
    this.buttonPadding,
    this.backgroundColor,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.semanticLabel,
    this.insetPadding =
        const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
    this.clipBehavior = Clip.none,
    this.shape,
    this.alignment,
    this.scrollable = false,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedTitle =
        titleText ?? (tomId != null ? resolveResourceOrFail('title') : null);
    final effectiveTitle =
        title ?? (resolvedTitle != null ? Text(resolvedTitle) : null);

    // Phase 2: Resolve optional parameters from resources
    final resolvedIconPadding =
        iconPadding ?? resolveEdgeInsetsOrNull('iconPadding');
    final resolvedIconColor =
        iconColor ?? resolveColorOrNull('iconColor');
    final resolvedTitlePadding =
        titlePadding ?? resolveEdgeInsetsOrNull('titlePadding');
    final resolvedContentPadding =
        contentPadding ?? resolveEdgeInsetsOrNull('contentPadding');
    final resolvedActionsPadding =
        actionsPadding ?? resolveEdgeInsetsOrNull('actionsPadding');
    final resolvedActionsOverflowButtonSpacing =
        actionsOverflowButtonSpacing ?? resolveDoubleOrNull('actionsOverflowButtonSpacing');
    final resolvedButtonPadding =
        buttonPadding ?? resolveEdgeInsetsOrNull('buttonPadding');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor');
    final resolvedSurfaceTintColor =
        surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    final resolvedSemanticLabel =
        semanticLabel ?? resolveResourceOrNull('semanticLabel');
    final resolvedInsetPadding =
        resolveEdgeInsetsOrNull('insetPadding') ?? insetPadding;
    final resolvedScrollable =
        resolveBoolOrNull('scrollable') ?? scrollable;

    // Phase 3: Resolve TextStyle from resources
    final resolvedTitleTextStyle =
        titleTextStyle ?? _resolveTextStyle('titleTextStyle');
    final resolvedContentTextStyle =
        contentTextStyle ?? _resolveTextStyle('contentTextStyle');

    return AlertDialog(
      icon: icon,
      iconPadding: resolvedIconPadding,
      iconColor: resolvedIconColor,
      title: effectiveTitle,
      titlePadding: resolvedTitlePadding,
      titleTextStyle: resolvedTitleTextStyle,
      content: content,
      contentPadding: resolvedContentPadding,
      contentTextStyle: resolvedContentTextStyle,
      actions: actions,
      actionsPadding: resolvedActionsPadding,
      actionsAlignment: actionsAlignment,
      actionsOverflowAlignment: actionsOverflowAlignment,
      actionsOverflowDirection: actionsOverflowDirection,
      actionsOverflowButtonSpacing: resolvedActionsOverflowButtonSpacing,
      buttonPadding: resolvedButtonPadding,
      backgroundColor: resolvedBackgroundColor,
      elevation: resolvedElevation,
      shadowColor: resolvedShadowColor,
      surfaceTintColor: resolvedSurfaceTintColor,
      semanticLabel: resolvedSemanticLabel,
      insetPadding: resolvedInsetPadding,
      clipBehavior: clipBehavior,
      shape: shape ?? _resolveShapeBorder('shape'),
      alignment: alignment ?? _resolveAlignment('alignment'),
      scrollable: resolvedScrollable,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
  }
}

/// Tom wrapper for [SimpleDialog].
///
/// Adds ID, group, authorization, and resource resolution.
class TomSimpleDialog extends TomDialogBase {
  final Widget? title;
  final String? titleText;
  final EdgeInsetsGeometry titlePadding;
  final TextStyle? titleTextStyle;
  final List<Widget>? children;
  final EdgeInsetsGeometry contentPadding;
  final Color? backgroundColor;
  final double? elevation;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final String? semanticLabel;
  final EdgeInsets? insetPadding;
  final Clip? clipBehavior;
  final ShapeBorder? shape;
  final AlignmentGeometry? alignment;

  TomSimpleDialog({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.title,
    this.titleText,
    this.titlePadding = const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0.0),
    this.titleTextStyle,
    this.children,
    this.contentPadding = const EdgeInsets.fromLTRB(0.0, 12.0, 0.0, 16.0),
    this.backgroundColor,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.semanticLabel,
    this.insetPadding,
    this.clipBehavior,
    this.shape,
    this.alignment,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedTitle =
        titleText ?? (tomId != null ? resolveResourceOrFail('title') : null);
    final effectiveTitle =
        title ?? (resolvedTitle != null ? Text(resolvedTitle) : null);

    // Phase 2: Resolve optional parameters from resources
    final resolvedTitlePadding =
        resolveEdgeInsetsOrNull('titlePadding') ?? titlePadding;
    final resolvedContentPadding =
        resolveEdgeInsetsOrNull('contentPadding') ?? contentPadding;
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor');
    final resolvedSurfaceTintColor =
        surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    final resolvedSemanticLabel =
        semanticLabel ?? resolveResourceOrNull('semanticLabel');
    final resolvedInsetPadding =
        insetPadding ?? resolveEdgeInsetsOrNull('insetPadding');

    // Phase 3: Resolve TextStyle from resources
    final resolvedTitleTextStyle =
        titleTextStyle ?? _resolveTextStyle('titleTextStyle');

    return SimpleDialog(
      title: effectiveTitle,
      titlePadding: resolvedTitlePadding,
      titleTextStyle: resolvedTitleTextStyle,
      contentPadding: resolvedContentPadding,
      backgroundColor: resolvedBackgroundColor,
      elevation: resolvedElevation,
      shadowColor: resolvedShadowColor,
      surfaceTintColor: resolvedSurfaceTintColor,
      semanticLabel: resolvedSemanticLabel,
      insetPadding: resolvedInsetPadding,
      clipBehavior: clipBehavior,
      shape: shape ?? _resolveShapeBorder('shape'),
      alignment: alignment ?? _resolveAlignment('alignment'),
      children: children,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
  }
}

/// Tom wrapper for [Dialog].
///
/// Adds ID, group, authorization, and resource resolution.
class TomDialog extends TomDialogBase {
  final Color? backgroundColor;
  final double? elevation;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final EdgeInsets? insetPadding;
  final Clip? clipBehavior;
  final ShapeBorder? shape;
  final AlignmentGeometry? alignment;
  final Widget? child;

  TomDialog({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.backgroundColor,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.insetPadding,
    this.clipBehavior,
    this.shape,
    this.alignment,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor');
    final resolvedSurfaceTintColor =
        surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    final resolvedInsetPadding =
        insetPadding ?? resolveEdgeInsetsOrNull('insetPadding');

    return Dialog(
      backgroundColor: resolvedBackgroundColor,
      elevation: resolvedElevation,
      shadowColor: resolvedShadowColor,
      surfaceTintColor: resolvedSurfaceTintColor,
      insetPadding: resolvedInsetPadding,
      clipBehavior: clipBehavior,
      shape: shape ?? _resolveShapeBorder('shape'),
      alignment: alignment ?? _resolveAlignment('alignment'),
      child: child,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
  }
}

/// Tom wrapper for [BottomSheet].
///
/// Adds ID, group, authorization, and resource resolution.
class TomBottomSheet extends TomDialogBase {
  final AnimationController? animationController;
  final VoidCallback onClosing;
  final WidgetBuilder builder;
  final Color? backgroundColor;
  final double? elevation;
  final ShapeBorder? shape;
  final Clip? clipBehavior;
  final BoxConstraints? constraints;
  final bool enableDrag;
  final bool? showDragHandle;
  final BottomSheetDragStartHandler? onDragStart;
  final BottomSheetDragEndHandler? onDragEnd;

  TomBottomSheet({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.animationController,
    required this.onClosing,
    required this.builder,
    this.backgroundColor,
    this.elevation,
    this.shape,
    this.clipBehavior,
    this.constraints,
    this.enableDrag = true,
    this.showDragHandle,
    this.onDragStart,
    this.onDragEnd,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');
    final resolvedEnableDrag =
        resolveBoolOrNull('enableDrag') ?? enableDrag;
    final resolvedShowDragHandle =
        showDragHandle ?? resolveBoolOrNull('showDragHandle');

    return BottomSheet(
      animationController: animationController,
      onClosing: onClosing,
      builder: builder,
      backgroundColor: resolvedBackgroundColor,
      elevation: resolvedElevation,
      shape: shape ?? _resolveShapeBorder('shape'),
      clipBehavior: clipBehavior,
      constraints: constraints ?? _resolveBoxConstraints('constraints'),
      enableDrag: resolvedEnableDrag,
      showDragHandle: resolvedShowDragHandle,
      onDragStart: onDragStart,
      onDragEnd: onDragEnd,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }

  BoxConstraints? _resolveBoxConstraints(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBoxConstraints(basePath!, suffix);
  }
}

/// Tom wrapper for [SnackBar] with construction-time resource resolution.
///
/// Extends [SnackBar] directly to pass `is SnackBar` checks.
///
/// Resources are resolved at construction time using [TomScope.current]
/// (or an explicit [scope] if provided). The following parameters support
/// resource resolution:
///
/// - [content] — if null, creates `TomText(tomId: '$tomId.content')`
/// - [backgroundColor] — resolved from `$tomId.backgroundColor`
/// - [elevation] — resolved from `$tomId.elevation`
/// - [margin] — resolved from `$tomId.margin`
/// - [padding] — resolved from `$tomId.padding`
/// - [closeIconColor] — resolved from `$tomId.closeIconColor`
///
/// ```dart
/// ScaffoldMessenger.of(context).showSnackBar(
///   TomSnackBar(
///     tomId: 'saveSuccess',  // Resolves content, colors from resources
///     action: TomSnackBarAction(tomId: 'undo', onPressed: handleUndo),
///   ),
/// );
/// ```
class TomSnackBar extends SnackBar {
  /// Tom ID for resource resolution.
  final String? tomId;

  /// Optional group membership.
  final TomUIGroup? tomGroup;

  /// Optional explicit scope for resource resolution.
  final TomScope? scope;

  /// Creates a Tom SnackBar with optional resource resolution.
  ///
  /// If [content] is null and [tomId] is provided, creates a default
  /// `TomText(tomId: '$tomId.content')` for the content.
  TomSnackBar({
    super.key,
    this.tomId,
    this.tomGroup,
    this.scope,
    Widget? content,
    Color? backgroundColor,
    double? elevation,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    super.width,
    super.shape,
    super.hitTestBehavior,
    super.behavior,
    super.action,
    super.actionOverflowThreshold,
    super.showCloseIcon,
    Color? closeIconColor,
    super.duration = const Duration(milliseconds: 4000),
    super.animation,
    super.onVisible,
    super.dismissDirection = DismissDirection.down,
    super.clipBehavior = Clip.hardEdge,
  }) : super(
          content: content ?? TomCtr.defaultTextOrEmpty(TomCtr.childTomId(tomId, 'content'), scope, tomGroup),
          backgroundColor: backgroundColor ?? TomCtr.color(_p(tomId, scope, 'backgroundColor')),
          elevation: elevation ?? TomCtr.doubleVal(_p(tomId, scope, 'elevation')),
          margin: margin ?? TomCtr.edgeInsets(_p(tomId, scope, 'margin')),
          padding: padding ?? TomCtr.edgeInsets(_p(tomId, scope, 'padding')),
          closeIconColor: closeIconColor ?? TomCtr.color(_p(tomId, scope, 'closeIconColor')),
        );

  /// Helper to build full path with suffix (for value resolution).
  static String? _p(String? tomId, TomScope? scope, String suffix) {
    final base = TomCtr.resolvePath(tomId, scope);
    return base != null ? '$base.$suffix' : null;
  }
}

/// Tom wrapper for [MaterialBanner].
///
/// Adds ID, group, authorization, and resource resolution.
class TomMaterialBanner extends TomDialogBase {
  final Widget content;
  final TextStyle? contentTextStyle;
  final List<Widget> actions;
  final double? elevation;
  final Widget? leading;
  final Color? backgroundColor;
  final Color? surfaceTintColor;
  final Color? shadowColor;
  final Color? dividerColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? leadingPadding;
  final bool forceActionsBelow;
  final OverflowBarAlignment overflowAlignment;
  final Animation<double>? animation;
  final VoidCallback? onVisible;

  TomMaterialBanner({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.content,
    this.contentTextStyle,
    required this.actions,
    this.elevation,
    this.leading,
    this.backgroundColor,
    this.surfaceTintColor,
    this.shadowColor,
    this.dividerColor,
    this.padding,
    this.margin,
    this.leadingPadding,
    this.forceActionsBelow = false,
    this.overflowAlignment = OverflowBarAlignment.end,
    this.animation,
    this.onVisible,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedSurfaceTintColor =
        surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor');
    final resolvedDividerColor =
        dividerColor ?? resolveColorOrNull('dividerColor');
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding');
    final resolvedMargin = margin ?? resolveEdgeInsetsOrNull('margin');
    final resolvedLeadingPadding =
        leadingPadding ?? resolveEdgeInsetsOrNull('leadingPadding');
    final resolvedForceActionsBelow =
        resolveBoolOrNull('forceActionsBelow') ?? forceActionsBelow;

    // Phase 3: Resolve TextStyle from resources
    final resolvedContentTextStyle =
        contentTextStyle ?? _resolveTextStyle('contentTextStyle');

    return MaterialBanner(
      content: content,
      contentTextStyle: resolvedContentTextStyle,
      actions: actions,
      elevation: resolvedElevation,
      leading: leading,
      backgroundColor: resolvedBackgroundColor,
      surfaceTintColor: resolvedSurfaceTintColor,
      shadowColor: resolvedShadowColor,
      dividerColor: resolvedDividerColor,
      padding: resolvedPadding,
      margin: resolvedMargin,
      leadingPadding: resolvedLeadingPadding,
      forceActionsBelow: resolvedForceActionsBelow,
      overflowAlignment: overflowAlignment,
      animation: animation,
      onVisible: onVisible,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }
}

/// Tom wrapper for [Tooltip].
///
/// Adds ID, group, authorization, and resource resolution.
class TomTooltip extends TomDialogBase {
  final String? message;
  final InlineSpan? richMessage;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? verticalOffset;
  final bool? preferBelow;
  final bool? excludeFromSemantics;
  final Decoration? decoration;
  final TextStyle? textStyle;
  final TextAlign? textAlign;
  final Duration? waitDuration;
  final Duration? showDuration;
  final Duration? exitDuration;
  final bool enableTapToDismiss;
  final TooltipTriggerMode? triggerMode;
  final bool? enableFeedback;
  final TooltipTriggeredCallback? onTriggered;
  final Widget? child;

  TomTooltip({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.message,
    this.richMessage,
    this.height,
    this.padding,
    this.margin,
    this.verticalOffset,
    this.preferBelow,
    this.excludeFromSemantics,
    this.decoration,
    this.textStyle,
    this.textAlign,
    this.waitDuration,
    this.showDuration,
    this.exitDuration,
    this.enableTapToDismiss = true,
    this.triggerMode,
    this.enableFeedback,
    this.onTriggered,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Tooltip requires exactly one of message or richMessage
    final String? resolvedMessage =
        richMessage != null ? null : (message ?? resolveResourceOrFail('tooltip'));

    // Phase 2: Resolve optional parameters from resources
    final resolvedHeight = height ?? resolveDoubleOrNull('height');
    final resolvedVerticalOffset =
        verticalOffset ?? resolveDoubleOrNull('verticalOffset');
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding');
    final resolvedMargin = margin ?? resolveEdgeInsetsOrNull('margin');

    // Phase 3: Resolve TextStyle from resources
    final resolvedTextStyle =
        textStyle ?? _resolveTextStyle('textStyle');
    final resolvedDecoration =
        decoration ?? _resolveDecoration('decoration');

    return Tooltip(
      message: resolvedMessage,
      richMessage: richMessage,
      height: resolvedHeight,
      padding: resolvedPadding,
      margin: resolvedMargin,
      verticalOffset: resolvedVerticalOffset,
      preferBelow: preferBelow,
      excludeFromSemantics: excludeFromSemantics,
      decoration: resolvedDecoration,
      textStyle: resolvedTextStyle,
      textAlign: textAlign,
      waitDuration: waitDuration,
      showDuration: showDuration,
      exitDuration: exitDuration,
      enableTapToDismiss: enableTapToDismiss,
      triggerMode: triggerMode,
      enableFeedback: enableFeedback,
      onTriggered: onTriggered,
      child: child,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }

  Decoration? _resolveDecoration(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveDecoration(basePath!, suffix);
  }
}

/// Tom wrapper for [CupertinoAlertDialog].
///
/// iOS-style alert dialog. Adds ID, group, authorization,
/// and resource resolution.
class TomCupertinoAlertDialog extends TomDialogBase {
  final Widget? title;
  final String? titleText;
  final Widget? content;
  final List<Widget> actions;
  final ScrollController? scrollController;
  final ScrollController? actionScrollController;
  final EdgeInsets? insetAnimationCurve;

  TomCupertinoAlertDialog({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.title,
    this.titleText,
    this.content,
    this.actions = const [],
    this.scrollController,
    this.actionScrollController,
    this.insetAnimationCurve,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedTitle =
        titleText ?? (tomId != null ? resolveResourceOrFail('title') : null);
    final effectiveTitle =
        title ?? (resolvedTitle != null ? Text(resolvedTitle) : null);

    return CupertinoAlertDialog(
      title: effectiveTitle,
      content: content,
      actions: actions,
      scrollController: scrollController,
      actionScrollController: actionScrollController,
    );
  }
}

/// Tom wrapper for [CupertinoActionSheet].
///
/// iOS-style action sheet. Adds ID, group, authorization,
/// and resource resolution.
class TomCupertinoActionSheet extends TomDialogBase {
  final Widget? title;
  final String? titleText;
  final Widget? message;
  final List<Widget> actions;
  final ScrollController? messageScrollController;
  final ScrollController? actionScrollController;
  final Widget? cancelButton;

  TomCupertinoActionSheet({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.title,
    this.titleText,
    this.message,
    this.actions = const [],
    this.messageScrollController,
    this.actionScrollController,
    this.cancelButton,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedTitle =
        titleText ?? (tomId != null ? resolveResourceOrFail('title') : null);
    final effectiveTitle =
        title ?? (resolvedTitle != null ? Text(resolvedTitle) : null);

    return CupertinoActionSheet(
      title: effectiveTitle,
      message: message,
      actions: actions,
      messageScrollController: messageScrollController,
      actionScrollController: actionScrollController,
      cancelButton: cancelButton,
    );
  }
}

/// Tom wrapper for [ModalBottomSheet] via [showModalBottomSheet].
///
/// This widget wraps the modal bottom sheet content for use when
/// building the child widget for a modal display.
/// Adds ID, group, authorization, and resource resolution.
class TomModalBottomSheet extends TomDialogBase {
  final WidgetBuilder builder;
  final Color? backgroundColor;
  final String? barrierLabel;
  final double? elevation;
  final ShapeBorder? shape;
  final Clip? clipBehavior;
  final BoxConstraints? constraints;
  final Color? barrierColor;
  final bool isScrollControlled;
  final double scrollControlDisabledMaxHeightRatio;
  final bool useRootNavigator;
  final bool isDismissible;
  final bool enableDrag;
  final bool? showDragHandle;
  final bool useSafeArea;
  final RouteSettings? routeSettings;
  final AnimationController? transitionAnimationController;
  final Offset? anchorPoint;

  TomModalBottomSheet({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.builder,
    this.backgroundColor,
    this.barrierLabel,
    this.elevation,
    this.shape,
    this.clipBehavior,
    this.constraints,
    this.barrierColor,
    this.isScrollControlled = false,
    this.scrollControlDisabledMaxHeightRatio = 9.0 / 16.0,
    this.useRootNavigator = false,
    this.isDismissible = true,
    this.enableDrag = true,
    this.showDragHandle,
    this.useSafeArea = false,
    this.routeSettings,
    this.transitionAnimationController,
    this.anchorPoint,
  });

  @override
  Widget buildContent(BuildContext context) {
    // This widget serves as a declarative configuration holder.
    // Use TomDialogs.showModalBottomSheet() for the imperative call.
    return builder(context);
  }
}

/// Tom-prefixed static wrappers for Flutter's function-based dialog APIs.
///
/// These wrap the standard `showDialog`, `showModalBottomSheet`, etc. and
/// provide consistent Tom ID resolution and authorization checks.
/// Function-based APIs cannot extend a widget base class, so they are
/// grouped as static methods on this utility class.
class TomDialogs {
  TomDialogs._();

  /// Wraps [showDialog]. Shows a material design dialog.
  static Future<T?> showDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool useSafeArea = true,
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
    Offset? anchorPoint,
    TraversalEdgeBehavior? traversalEdgeBehavior,
  }) {
    return material.showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      anchorPoint: anchorPoint,
      traversalEdgeBehavior: traversalEdgeBehavior,
    );
  }

  /// Wraps [showModalBottomSheet]. Shows a material design modal bottom sheet.
  static Future<T?> showModalBottomSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    Color? backgroundColor,
    String? barrierLabel,
    double? elevation,
    ShapeBorder? shape,
    Clip? clipBehavior,
    BoxConstraints? constraints,
    Color? barrierColor,
    bool isScrollControlled = false,
    double scrollControlDisabledMaxHeightRatio = 9.0 / 16.0,
    bool useRootNavigator = false,
    bool isDismissible = true,
    bool enableDrag = true,
    bool? showDragHandle,
    bool useSafeArea = false,
    RouteSettings? routeSettings,
    AnimationController? transitionAnimationController,
    Offset? anchorPoint,
  }) {
    return material.showModalBottomSheet<T>(
      context: context,
      builder: builder,
      backgroundColor: backgroundColor,
      barrierLabel: barrierLabel,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      constraints: constraints,
      barrierColor: barrierColor,
      isScrollControlled: isScrollControlled,
      scrollControlDisabledMaxHeightRatio:
          scrollControlDisabledMaxHeightRatio,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      showDragHandle: showDragHandle,
      useSafeArea: useSafeArea,
      routeSettings: routeSettings,
      transitionAnimationController: transitionAnimationController,
      anchorPoint: anchorPoint,
    );
  }

  /// Wraps [showDatePicker]. Shows a material design date picker.
  static Future<DateTime?> showDatePicker({
    required BuildContext context,
    DateTime? initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    DateTime? currentDate,
    DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
    SelectableDayPredicate? selectableDayPredicate,
    String? helpText,
    String? cancelText,
    String? confirmText,
    Locale? locale,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
    TextDirection? textDirection,
    TransitionBuilder? builder,
    DatePickerMode initialDatePickerMode = DatePickerMode.day,
    String? errorFormatText,
    String? errorInvalidText,
    String? fieldHintText,
    String? fieldLabelText,
    TextInputType? keyboardType,
    Offset? anchorPoint,
    ValueChanged<DatePickerEntryMode>? onDatePickerModeChange,
    Icon? switchToInputEntryModeIcon,
    Icon? switchToCalendarEntryModeIcon,
  }) {
    return material.showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      currentDate: currentDate,
      initialEntryMode: initialEntryMode,
      selectableDayPredicate: selectableDayPredicate,
      helpText: helpText,
      cancelText: cancelText,
      confirmText: confirmText,
      locale: locale,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      textDirection: textDirection,
      builder: builder,
      initialDatePickerMode: initialDatePickerMode,
      errorFormatText: errorFormatText,
      errorInvalidText: errorInvalidText,
      fieldHintText: fieldHintText,
      fieldLabelText: fieldLabelText,
      keyboardType: keyboardType,
      anchorPoint: anchorPoint,
      onDatePickerModeChange: onDatePickerModeChange,
      switchToInputEntryModeIcon: switchToInputEntryModeIcon,
      switchToCalendarEntryModeIcon: switchToCalendarEntryModeIcon,
    );
  }

  /// Wraps [showTimePicker]. Shows a material design time picker.
  static Future<TimeOfDay?> showTimePicker({
    required BuildContext context,
    required TimeOfDay initialTime,
    TransitionBuilder? builder,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool useRootNavigator = true,
    TimePickerEntryMode initialEntryMode = TimePickerEntryMode.dial,
    String? cancelText,
    String? confirmText,
    String? helpText,
    String? errorInvalidText,
    String? hourLabelText,
    String? minuteLabelText,
    RouteSettings? routeSettings,
    EntryModeChangeCallback? onEntryModeChanged,
    Offset? anchorPoint,
    Orientation? orientation,
  }) {
    return material.showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      useRootNavigator: useRootNavigator,
      initialEntryMode: initialEntryMode,
      cancelText: cancelText,
      confirmText: confirmText,
      helpText: helpText,
      errorInvalidText: errorInvalidText,
      hourLabelText: hourLabelText,
      minuteLabelText: minuteLabelText,
      routeSettings: routeSettings,
      onEntryModeChanged: onEntryModeChanged,
      anchorPoint: anchorPoint,
      orientation: orientation,
    );
  }

  /// Wraps [showDateRangePicker]. Shows a full-screen date range picker.
  static Future<DateTimeRange?> showDateRangePicker({
    required BuildContext context,
    DateTimeRange? initialDateRange,
    required DateTime firstDate,
    required DateTime lastDate,
    DateTime? currentDate,
    DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
    String? helpText,
    String? cancelText,
    String? confirmText,
    String? saveText,
    String? errorFormatText,
    String? errorInvalidText,
    String? errorInvalidRangeText,
    String? fieldStartHintText,
    String? fieldEndHintText,
    String? fieldStartLabelText,
    String? fieldEndLabelText,
    Locale? locale,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
    TextDirection? textDirection,
    TransitionBuilder? builder,
    Offset? anchorPoint,
    TextInputType keyboardType = TextInputType.datetime,
    Icon? switchToInputEntryModeIcon,
    Icon? switchToCalendarEntryModeIcon,
  }) {
    return material.showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: firstDate,
      lastDate: lastDate,
      currentDate: currentDate,
      initialEntryMode: initialEntryMode,
      helpText: helpText,
      cancelText: cancelText,
      confirmText: confirmText,
      saveText: saveText,
      errorFormatText: errorFormatText,
      errorInvalidText: errorInvalidText,
      errorInvalidRangeText: errorInvalidRangeText,
      fieldStartHintText: fieldStartHintText,
      fieldEndHintText: fieldEndHintText,
      fieldStartLabelText: fieldStartLabelText,
      fieldEndLabelText: fieldEndLabelText,
      locale: locale,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      textDirection: textDirection,
      builder: builder,
      anchorPoint: anchorPoint,
      keyboardType: keyboardType,
      switchToInputEntryModeIcon: switchToInputEntryModeIcon,
      switchToCalendarEntryModeIcon: switchToCalendarEntryModeIcon,
    );
  }

  /// Wraps [showMenu]. Shows a popup menu at the given position.
  static Future<T?> showMenu<T>({
    required BuildContext context,
    required RelativeRect position,
    required List<PopupMenuEntry<T>> items,
    T? initialValue,
    double? elevation,
    Color? shadowColor,
    Color? surfaceTintColor,
    String? semanticLabel,
    ShapeBorder? shape,
    Color? color,
    bool useRootNavigator = false,
    BoxConstraints? constraints,
    Clip clipBehavior = Clip.none,
    RouteSettings? routeSettings,
    AnimationStyle? popUpAnimationStyle,
  }) {
    return material.showMenu<T>(
      context: context,
      position: position,
      items: items,
      initialValue: initialValue,
      elevation: elevation,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      semanticLabel: semanticLabel,
      shape: shape,
      color: color,
      useRootNavigator: useRootNavigator,
      constraints: constraints,
      clipBehavior: clipBehavior,
      routeSettings: routeSettings,
      popUpAnimationStyle: popUpAnimationStyle,
    );
  }

  /// Wraps [showSearch]. Shows a full-screen search page.
  static Future<T?> showSearch<T>({
    required BuildContext context,
    required SearchDelegate<T> delegate,
    String? query = '',
    bool useRootNavigator = false,
  }) {
    return material.showSearch<T>(
      context: context,
      delegate: delegate,
      query: query,
      useRootNavigator: useRootNavigator,
    );
  }
}

// ============================================================================
// Section II: Extended Dialog Widgets
// ============================================================================

/// Tom wrapper for [AboutDialog].
///
/// App About dialog. Auth on about access; resources for app strings.
class TomAboutDialog extends TomDialogBase {
  final String? applicationName;
  final String? applicationVersion;
  final Widget? applicationIcon;
  final String? applicationLegalese;
  final List<Widget>? children;

  TomAboutDialog({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.applicationName,
    this.applicationVersion,
    this.applicationIcon,
    this.applicationLegalese,
    this.children,
  });

  @override
  Widget buildContent(BuildContext context) {
    return AboutDialog(
      applicationName: applicationName ??
          (tomId != null ? resolveResourceOrFail('applicationName') : null),
      applicationVersion: applicationVersion ??
          (tomId != null
              ? resolveResourceOrFail('applicationVersion')
              : null),
      applicationIcon: applicationIcon,
      applicationLegalese: applicationLegalese ??
          (tomId != null
              ? resolveResourceOrFail('applicationLegalese')
              : null),
      children: children,
    );
  }
}

/// Tom wrapper for [CupertinoContextMenu].
///
/// Long-press context menu. Auth controls context menu access.
class TomCupertinoContextMenu extends TomDialogBase {
  final Widget child;
  final List<Widget> actions;
  final bool? enableHapticFeedback;

  TomCupertinoContextMenu({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.child,
    required this.actions,
    this.enableHapticFeedback,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedEnableHapticFeedback =
        enableHapticFeedback ?? resolveBoolOrNull('enableHapticFeedback') ?? false;

    return CupertinoContextMenu(
      actions: actions,
      enableHapticFeedback: resolvedEnableHapticFeedback,
      child: child,
    );
  }
}

/// Tom wrapper for [DatePickerDialog].
///
/// Date picker dialog. Auth for readonly; resources for text strings.
class TomDatePickerDialog extends TomDialogBase {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? currentDate;
  final DatePickerEntryMode initialEntryMode;
  final SelectableDayPredicate? selectableDayPredicate;
  final String? cancelText;
  final String? confirmText;
  final String? helpText;
  final DatePickerMode initialCalendarMode;
  final String? errorFormatText;
  final String? errorInvalidText;
  final String? fieldHintText;
  final String? fieldLabelText;
  final TextInputType? keyboardType;
  final Icon? switchToInputEntryModeIcon;
  final Icon? switchToCalendarEntryModeIcon;

  TomDatePickerDialog({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.currentDate,
    this.initialEntryMode = DatePickerEntryMode.calendar,
    this.selectableDayPredicate,
    this.cancelText,
    this.confirmText,
    this.helpText,
    this.initialCalendarMode = DatePickerMode.day,
    this.errorFormatText,
    this.errorInvalidText,
    this.fieldHintText,
    this.fieldLabelText,
    this.keyboardType,
    this.switchToInputEntryModeIcon,
    this.switchToCalendarEntryModeIcon,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedKeyboardType =
        keyboardType ?? _resolveTextInputType(resolveResourceOrNull('keyboardType'));

    return DatePickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      currentDate: currentDate,
      initialEntryMode: initialEntryMode,
      selectableDayPredicate: selectableDayPredicate,
      cancelText:
          cancelText ?? (tomId != null ? resolveResourceOrFail('cancel') : null),
      confirmText:
          confirmText ?? (tomId != null ? resolveResourceOrFail('confirm') : null),
      helpText:
          helpText ?? (tomId != null ? resolveResourceOrFail('help') : null),
      initialCalendarMode: initialCalendarMode,
      errorFormatText: errorFormatText ??
          (tomId != null ? resolveResourceOrFail('errorFormat') : null),
      errorInvalidText: errorInvalidText ??
          (tomId != null ? resolveResourceOrFail('errorInvalid') : null),
      fieldHintText: fieldHintText ??
          (tomId != null ? resolveResourceOrFail('fieldHint') : null),
      fieldLabelText: fieldLabelText ??
          (tomId != null ? resolveResourceOrFail('fieldLabel') : null),
      keyboardType: resolvedKeyboardType,
      switchToInputEntryModeIcon: switchToInputEntryModeIcon,
      switchToCalendarEntryModeIcon: switchToCalendarEntryModeIcon,
    );
  }
}

/// Tom wrapper for [DateRangePickerDialog].
///
/// Date range picker dialog. Auth for readonly; resources for text strings.
class TomDateRangePickerDialog extends TomDialogBase {
  final DateTimeRange? initialDateRange;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? currentDate;
  final DatePickerEntryMode initialEntryMode;
  final String? helpText;
  final String? cancelText;
  final String? confirmText;
  final String? saveText;
  final String? errorFormatText;
  final String? errorInvalidText;
  final String? errorInvalidRangeText;
  final String? fieldStartHintText;
  final String? fieldEndHintText;
  final String? fieldStartLabelText;
  final String? fieldEndLabelText;
  final TextInputType? keyboardType;
  final Icon? switchToInputEntryModeIcon;
  final Icon? switchToCalendarEntryModeIcon;

  TomDateRangePickerDialog({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.initialDateRange,
    required this.firstDate,
    required this.lastDate,
    this.currentDate,
    this.initialEntryMode = DatePickerEntryMode.calendar,
    this.helpText,
    this.cancelText,
    this.confirmText,
    this.saveText,
    this.errorFormatText,
    this.errorInvalidText,
    this.errorInvalidRangeText,
    this.fieldStartHintText,
    this.fieldEndHintText,
    this.fieldStartLabelText,
    this.fieldEndLabelText,
    this.keyboardType,
    this.switchToInputEntryModeIcon,
    this.switchToCalendarEntryModeIcon,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedKeyboardType =
        keyboardType ?? _resolveTextInputType(resolveResourceOrNull('keyboardType')) ?? TextInputType.datetime;

    return DateRangePickerDialog(
      initialDateRange: initialDateRange,
      firstDate: firstDate,
      lastDate: lastDate,
      currentDate: currentDate,
      initialEntryMode: initialEntryMode,
      helpText:
          helpText ?? (tomId != null ? resolveResourceOrFail('help') : null),
      cancelText:
          cancelText ?? (tomId != null ? resolveResourceOrFail('cancel') : null),
      confirmText:
          confirmText ?? (tomId != null ? resolveResourceOrFail('confirm') : null),
      saveText:
          saveText ?? (tomId != null ? resolveResourceOrFail('save') : null),
      errorFormatText: errorFormatText ??
          (tomId != null ? resolveResourceOrFail('errorFormat') : null),
      errorInvalidText: errorInvalidText ??
          (tomId != null ? resolveResourceOrFail('errorInvalid') : null),
      errorInvalidRangeText: errorInvalidRangeText ??
          (tomId != null ? resolveResourceOrFail('errorInvalidRange') : null),
      fieldStartHintText: fieldStartHintText ??
          (tomId != null ? resolveResourceOrFail('fieldStartHint') : null),
      fieldEndHintText: fieldEndHintText ??
          (tomId != null ? resolveResourceOrFail('fieldEndHint') : null),
      fieldStartLabelText: fieldStartLabelText ??
          (tomId != null ? resolveResourceOrFail('fieldStartLabel') : null),
      fieldEndLabelText: fieldEndLabelText ??
          (tomId != null ? resolveResourceOrFail('fieldEndLabel') : null),
      keyboardType: resolvedKeyboardType,
      switchToInputEntryModeIcon: switchToInputEntryModeIcon,
      switchToCalendarEntryModeIcon: switchToCalendarEntryModeIcon,
    );
  }
}

/// Tom wrapper for [TimePickerDialog].
///
/// Time picker dialog. Auth for readonly; resources for text strings.
class TomTimePickerDialog extends TomDialogBase {
  final TimeOfDay initialTime;
  final String? cancelText;
  final String? confirmText;
  final String? helpText;
  final String? errorInvalidText;
  final String? hourLabelText;
  final String? minuteLabelText;
  final TimePickerEntryMode initialEntryMode;
  final Orientation? orientation;
  final EntryModeChangeCallback? onEntryModeChanged;

  TomTimePickerDialog({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.initialTime,
    this.cancelText,
    this.confirmText,
    this.helpText,
    this.errorInvalidText,
    this.hourLabelText,
    this.minuteLabelText,
    this.initialEntryMode = TimePickerEntryMode.dial,
    this.orientation,
    this.onEntryModeChanged,
  });

  @override
  Widget buildContent(BuildContext context) {
    return TimePickerDialog(
      initialTime: initialTime,
      cancelText:
          cancelText ?? (tomId != null ? resolveResourceOrFail('cancel') : null),
      confirmText:
          confirmText ?? (tomId != null ? resolveResourceOrFail('confirm') : null),
      helpText:
          helpText ?? (tomId != null ? resolveResourceOrFail('help') : null),
      errorInvalidText: errorInvalidText ??
          (tomId != null ? resolveResourceOrFail('errorInvalid') : null),
      hourLabelText: hourLabelText ??
          (tomId != null ? resolveResourceOrFail('hourLabel') : null),
      minuteLabelText: minuteLabelText ??
          (tomId != null ? resolveResourceOrFail('minuteLabel') : null),
      initialEntryMode: initialEntryMode,
      orientation: orientation,
      onEntryModeChanged: onEntryModeChanged,
    );
  }
}

TextInputType? _resolveTextInputType(String? value) {
  if (value == null || value.isEmpty) return null;
  switch (value.toLowerCase()) {
    case 'text':
      return TextInputType.text;
    case 'multiline':
      return TextInputType.multiline;
    case 'number':
      return TextInputType.number;
    case 'phone':
      return TextInputType.phone;
    case 'datetime':
      return TextInputType.datetime;
    case 'emailaddress':
      return TextInputType.emailAddress;
    case 'url':
      return TextInputType.url;
    case 'visiblepassword':
      return TextInputType.visiblePassword;
    case 'name':
      return TextInputType.name;
    case 'streetaddress':
      return TextInputType.streetAddress;
    case 'none':
      return TextInputType.none;
    default:
      return null;
  }
}

/// Tom wrapper for [SimpleDialogOption].
///
/// Option item within SimpleDialog. Auth controls which options appear.
class TomSimpleDialogOption extends TomDialogBase {
  final VoidCallback? onPressed;
  final EdgeInsets? padding;
  final Widget? child;

  TomSimpleDialogOption({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.onPressed,
    this.padding,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedPadding = padding ?? resolveEdgeInsetsOrNull('padding');

    return SimpleDialogOption(
      onPressed: onPressed,
      padding: resolvedPadding,
      child: child,
    );
  }
}

/// Tom wrapper for [LicensePage].
///
/// License listing page. Auth on access; resources for app strings.
class TomLicensePage extends TomDialogBase {
  final String? applicationName;
  final String? applicationVersion;
  final Widget? applicationIcon;
  final String? applicationLegalese;

  TomLicensePage({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.applicationName,
    this.applicationVersion,
    this.applicationIcon,
    this.applicationLegalese,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedApplicationName =
      applicationName ?? resolveResourceOrNull('applicationName');
    final resolvedApplicationVersion =
      applicationVersion ?? resolveResourceOrNull('applicationVersion');
    final resolvedApplicationLegalese =
      applicationLegalese ?? resolveResourceOrNull('applicationLegalese');

    return LicensePage(
      applicationName: resolvedApplicationName,
      applicationVersion: resolvedApplicationVersion,
      applicationIcon: applicationIcon,
      applicationLegalese: resolvedApplicationLegalese,
    );
  }
}
