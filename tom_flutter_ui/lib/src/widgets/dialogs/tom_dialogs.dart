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

import '../../groups/tom_auth_gate.dart';
import '../../groups/tom_widget_mixin.dart';
import '../../widget_base/tom_construction_helpers.dart';
import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_node_base.dart';
import '../../widget_base/tom_scope_widgets.dart';
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

  // Pre-resolved resource values
  late final String? _resolvedTitle;
  late final EdgeInsetsGeometry? _resolvedIconPadding;
  late final Color? _resolvedIconColor;
  late final EdgeInsetsGeometry? _resolvedTitlePadding;
  late final EdgeInsetsGeometry? _resolvedContentPadding;
  late final EdgeInsetsGeometry? _resolvedActionsPadding;
  late final double? _resolvedActionsOverflowButtonSpacing;
  late final EdgeInsetsGeometry? _resolvedButtonPadding;
  late final Color? _resolvedBackgroundColor;
  late final double? _resolvedElevation;
  late final Color? _resolvedShadowColor;
  late final Color? _resolvedSurfaceTintColor;
  late final String? _resolvedSemanticLabel;
  late final EdgeInsets _resolvedInsetPadding;
  late final bool _resolvedScrollable;
  late final TextStyle? _resolvedTitleTextStyle;
  late final TextStyle? _resolvedContentTextStyle;
  late final ShapeBorder? _resolvedShape;
  late final AlignmentGeometry? _resolvedAlignment;

  TomAlertDialog({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
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
  }) {
    _resolvedTitle = titleText ?? (tomId != null ? TomCtr.textOrFail(basePath, 'title') : null);
    _resolvedIconPadding = iconPadding ?? TomCtr.edgeInsets(basePath, 'iconPadding');
    _resolvedIconColor = iconColor ?? TomCtr.color(basePath, 'iconColor');
    _resolvedTitlePadding = titlePadding ?? TomCtr.edgeInsets(basePath, 'titlePadding');
    _resolvedContentPadding = contentPadding ?? TomCtr.edgeInsets(basePath, 'contentPadding');
    _resolvedActionsPadding = actionsPadding ?? TomCtr.edgeInsets(basePath, 'actionsPadding');
    _resolvedActionsOverflowButtonSpacing = actionsOverflowButtonSpacing ?? TomCtr.doubleVal(basePath, 'actionsOverflowButtonSpacing');
    _resolvedButtonPadding = buttonPadding ?? TomCtr.edgeInsets(basePath, 'buttonPadding');
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedElevation = elevation ?? TomCtr.doubleVal(basePath, 'elevation');
    _resolvedShadowColor = shadowColor ?? TomCtr.color(basePath, 'shadowColor');
    _resolvedSurfaceTintColor = surfaceTintColor ?? TomCtr.color(basePath, 'surfaceTintColor');
    _resolvedSemanticLabel = semanticLabel ?? TomCtr.textOrNull(basePath, 'semanticLabel');
    _resolvedInsetPadding = TomCtr.edgeInsets(basePath, 'insetPadding') ?? insetPadding;
    _resolvedScrollable = TomCtr.boolVal(basePath, 'scrollable') ?? scrollable;
    _resolvedTitleTextStyle = titleTextStyle ?? _resolveTextStyle('titleTextStyle');
    _resolvedContentTextStyle = contentTextStyle ?? _resolveTextStyle('contentTextStyle');
    _resolvedShape = shape ?? _resolveShapeBorder('shape');
    _resolvedAlignment = alignment ?? _resolveAlignment('alignment');
  }

  @override
  Widget buildContent(BuildContext context) {
    final effectiveTitle =
        title ?? (_resolvedTitle != null ? Text(_resolvedTitle) : null);

    return AlertDialog(
      icon: icon,
      iconPadding: _resolvedIconPadding,
      iconColor: _resolvedIconColor,
      title: effectiveTitle,
      titlePadding: _resolvedTitlePadding,
      titleTextStyle: _resolvedTitleTextStyle,
      content: content,
      contentPadding: _resolvedContentPadding,
      contentTextStyle: _resolvedContentTextStyle,
      actions: actions,
      actionsPadding: _resolvedActionsPadding,
      actionsAlignment: actionsAlignment,
      actionsOverflowAlignment: actionsOverflowAlignment,
      actionsOverflowDirection: actionsOverflowDirection,
      actionsOverflowButtonSpacing: _resolvedActionsOverflowButtonSpacing,
      buttonPadding: _resolvedButtonPadding,
      backgroundColor: _resolvedBackgroundColor,
      elevation: _resolvedElevation,
      shadowColor: _resolvedShadowColor,
      surfaceTintColor: _resolvedSurfaceTintColor,
      semanticLabel: _resolvedSemanticLabel,
      insetPadding: _resolvedInsetPadding,
      clipBehavior: clipBehavior,
      shape: _resolvedShape,
      alignment: _resolvedAlignment,
      scrollable: _resolvedScrollable,
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

  // Pre-resolved resource values
  late final String? _resolvedTitle;
  late final EdgeInsetsGeometry _resolvedTitlePadding;
  late final EdgeInsetsGeometry _resolvedContentPadding;
  late final Color? _resolvedBackgroundColor;
  late final double? _resolvedElevation;
  late final Color? _resolvedShadowColor;
  late final Color? _resolvedSurfaceTintColor;
  late final String? _resolvedSemanticLabel;
  late final EdgeInsets? _resolvedInsetPadding;
  late final TextStyle? _resolvedTitleTextStyle;
  late final ShapeBorder? _resolvedShape;
  late final AlignmentGeometry? _resolvedAlignment;

  TomSimpleDialog({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
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
  }) {
    _resolvedTitle = titleText ?? (tomId != null ? TomCtr.textOrFail(basePath, 'title') : null);
    _resolvedTitlePadding = TomCtr.edgeInsets(basePath, 'titlePadding') ?? titlePadding;
    _resolvedContentPadding = TomCtr.edgeInsets(basePath, 'contentPadding') ?? contentPadding;
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedElevation = elevation ?? TomCtr.doubleVal(basePath, 'elevation');
    _resolvedShadowColor = shadowColor ?? TomCtr.color(basePath, 'shadowColor');
    _resolvedSurfaceTintColor = surfaceTintColor ?? TomCtr.color(basePath, 'surfaceTintColor');
    _resolvedSemanticLabel = semanticLabel ?? TomCtr.textOrNull(basePath, 'semanticLabel');
    _resolvedInsetPadding = insetPadding ?? TomCtr.edgeInsets(basePath, 'insetPadding');
    _resolvedTitleTextStyle = titleTextStyle ?? _resolveTextStyle('titleTextStyle');
    _resolvedShape = shape ?? _resolveShapeBorder('shape');
    _resolvedAlignment = alignment ?? _resolveAlignment('alignment');
  }

  @override
  Widget buildContent(BuildContext context) {
    final effectiveTitle =
        title ?? (_resolvedTitle != null ? Text(_resolvedTitle) : null);

    return SimpleDialog(
      title: effectiveTitle,
      titlePadding: _resolvedTitlePadding,
      titleTextStyle: _resolvedTitleTextStyle,
      contentPadding: _resolvedContentPadding,
      backgroundColor: _resolvedBackgroundColor,
      elevation: _resolvedElevation,
      shadowColor: _resolvedShadowColor,
      surfaceTintColor: _resolvedSurfaceTintColor,
      semanticLabel: _resolvedSemanticLabel,
      insetPadding: _resolvedInsetPadding,
      clipBehavior: clipBehavior,
      shape: _resolvedShape,
      alignment: _resolvedAlignment,
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

  // Pre-resolved resource values
  late final Color? _resolvedBackgroundColor;
  late final double? _resolvedElevation;
  late final Color? _resolvedShadowColor;
  late final Color? _resolvedSurfaceTintColor;
  late final EdgeInsets? _resolvedInsetPadding;
  late final ShapeBorder? _resolvedShape;
  late final AlignmentGeometry? _resolvedAlignment;

  TomDialog({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    this.backgroundColor,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.insetPadding,
    this.clipBehavior,
    this.shape,
    this.alignment,
    this.child,
  }) {
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedElevation = elevation ?? TomCtr.doubleVal(basePath, 'elevation');
    _resolvedShadowColor = shadowColor ?? TomCtr.color(basePath, 'shadowColor');
    _resolvedSurfaceTintColor = surfaceTintColor ?? TomCtr.color(basePath, 'surfaceTintColor');
    _resolvedInsetPadding = insetPadding ?? TomCtr.edgeInsets(basePath, 'insetPadding');
    _resolvedShape = shape ?? _resolveShapeBorder('shape');
    _resolvedAlignment = alignment ?? _resolveAlignment('alignment');
  }

  @override
  Widget buildContent(BuildContext context) {
    return Dialog(
      backgroundColor: _resolvedBackgroundColor,
      elevation: _resolvedElevation,
      shadowColor: _resolvedShadowColor,
      surfaceTintColor: _resolvedSurfaceTintColor,
      insetPadding: _resolvedInsetPadding,
      clipBehavior: clipBehavior,
      shape: _resolvedShape,
      alignment: _resolvedAlignment,
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

  // Pre-resolved resource values
  late final Color? _resolvedBackgroundColor;
  late final double? _resolvedElevation;
  late final bool _resolvedEnableDrag;
  late final bool? _resolvedShowDragHandle;
  late final ShapeBorder? _resolvedShape;
  late final BoxConstraints? _resolvedConstraints;

  TomBottomSheet({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    this.animationController,
    required VoidCallback onClosing,
    required WidgetBuilder builder,
    this.backgroundColor,
    this.elevation,
    this.shape,
    this.clipBehavior,
    this.constraints,
    this.enableDrag = true,
    this.showDragHandle,
    BottomSheetDragStartHandler? onDragStart,
    BottomSheetDragEndHandler? onDragEnd,
  }) : builder = InScopeBuilder(scope: scope).wrap1(builder),
       onClosing = InScopeBuilder(scope: scope).wrap0(onClosing),
       onDragStart = InScopeBuilder(scope: scope).wrap1n(onDragStart),
       onDragEnd = _wrapDragEndHandler(scope, onDragEnd) {
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedElevation = elevation ?? TomCtr.doubleVal(basePath, 'elevation');
    _resolvedEnableDrag = TomCtr.boolVal(basePath, 'enableDrag') ?? enableDrag;
    _resolvedShowDragHandle = showDragHandle ?? TomCtr.boolVal(basePath, 'showDragHandle');
    _resolvedShape = shape ?? _resolveShapeBorder('shape');
    _resolvedConstraints = constraints ?? _resolveBoxConstraints('constraints');
  }

  @override
  Widget buildContent(BuildContext context) {
    return BottomSheet(
      animationController: animationController,
      onClosing: onClosing,
      builder: builder,
      backgroundColor: _resolvedBackgroundColor,
      elevation: _resolvedElevation,
      shape: _resolvedShape,
      clipBehavior: clipBehavior,
      constraints: _resolvedConstraints,
      enableDrag: _resolvedEnableDrag,
      showDragHandle: _resolvedShowDragHandle,
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
/// Extends [SnackBar] directly to pass `is SnackBar` checks. [SnackBar]'s
/// `State` is private to the framework, so this wrapper cannot gate itself by
/// wrapping `super.build`; [content] carries a [TomAuthGate] instead.
///
/// Gating the content alone would leave an empty bar sliding up, which answers
/// neither "shown" nor "hidden". A snack bar is presented imperatively rather
/// than composed, so the place its visibility can actually be enforced is the
/// call that presents it: [TomMessenger] reads [effectiveAuthState] and
/// declines to show a bar that resolves to [TomAuthState.none].
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
/// TomMessenger.showSnackBar(
///   context,
///   TomSnackBar(
///     tomId: 'saveSuccess',  // Resolves content, colors from resources
///     action: TomSnackBarAction(tomId: 'undo', onPressed: handleUndo),
///   ),
/// );
/// ```
class TomSnackBar extends SnackBar with TomWidgetMixin {
  /// Tom ID for resource resolution.
  @override
  final String? tomId;

  /// Optional group membership.
  @override
  final TomAuthorizationGroup? tomGroup;

  /// Optional explicit scope for resource resolution.
  @override
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
          content: TomAuthGate(
            tomId: tomId,
            tomGroup: tomGroup,
            scope: scope,
            child: content ??
                TomCtr.defaultTextOrEmpty(
                    TomCtr.childTomId(tomId, 'content'), scope, tomGroup),
          ),
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

  // Pre-resolved resource values
  late final double? _resolvedElevation;
  late final Color? _resolvedBackgroundColor;
  late final Color? _resolvedSurfaceTintColor;
  late final Color? _resolvedShadowColor;
  late final Color? _resolvedDividerColor;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final EdgeInsetsGeometry? _resolvedMargin;
  late final EdgeInsetsGeometry? _resolvedLeadingPadding;
  late final bool _resolvedForceActionsBelow;
  late final TextStyle? _resolvedContentTextStyle;

  TomMaterialBanner({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
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
    VoidCallback? onVisible,
  })  : onVisible = InScopeBuilder(scope: scope).wrap0n(onVisible) {
    _resolvedElevation = elevation ?? TomCtr.doubleVal(basePath, 'elevation');
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedSurfaceTintColor = surfaceTintColor ?? TomCtr.color(basePath, 'surfaceTintColor');
    _resolvedShadowColor = shadowColor ?? TomCtr.color(basePath, 'shadowColor');
    _resolvedDividerColor = dividerColor ?? TomCtr.color(basePath, 'dividerColor');
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
    _resolvedMargin = margin ?? TomCtr.edgeInsets(basePath, 'margin');
    _resolvedLeadingPadding = leadingPadding ?? TomCtr.edgeInsets(basePath, 'leadingPadding');
    _resolvedForceActionsBelow = TomCtr.boolVal(basePath, 'forceActionsBelow') ?? forceActionsBelow;
    _resolvedContentTextStyle = contentTextStyle ?? _resolveTextStyle('contentTextStyle');
  }

  @override
  Widget buildContent(BuildContext context) {
    return MaterialBanner(
      content: content,
      contentTextStyle: _resolvedContentTextStyle,
      actions: actions,
      elevation: _resolvedElevation,
      leading: leading,
      backgroundColor: _resolvedBackgroundColor,
      surfaceTintColor: _resolvedSurfaceTintColor,
      shadowColor: _resolvedShadowColor,
      dividerColor: _resolvedDividerColor,
      padding: _resolvedPadding,
      margin: _resolvedMargin,
      leadingPadding: _resolvedLeadingPadding,
      forceActionsBelow: _resolvedForceActionsBelow,
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

  // Pre-resolved resource values
  late final String? _resolvedMessage;
  late final double? _resolvedHeight;
  late final double? _resolvedVerticalOffset;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final EdgeInsetsGeometry? _resolvedMargin;
  late final TextStyle? _resolvedTextStyle;
  late final Decoration? _resolvedDecoration;

  TomTooltip({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
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
    TooltipTriggeredCallback? onTriggered,
    this.child,
  })  : onTriggered = InScopeBuilder(scope: scope).wrap0n(onTriggered) {
    _resolvedMessage = richMessage != null ? null : (message ?? TomCtr.textOrFail(basePath, 'tooltip'));
    _resolvedHeight = height ?? TomCtr.doubleVal(basePath, 'height');
    _resolvedVerticalOffset = verticalOffset ?? TomCtr.doubleVal(basePath, 'verticalOffset');
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
    _resolvedMargin = margin ?? TomCtr.edgeInsets(basePath, 'margin');
    _resolvedTextStyle = textStyle ?? _resolveTextStyle('textStyle');
    _resolvedDecoration = decoration ?? _resolveDecoration('decoration');
  }

  @override
  Widget buildContent(BuildContext context) {
    // Tooltip requires exactly one of message or richMessage

    return Tooltip(
      message: _resolvedMessage,
      richMessage: richMessage,
      constraints: _resolvedHeight != null ? BoxConstraints(minHeight: _resolvedHeight) : null,
      padding: _resolvedPadding,
      margin: _resolvedMargin,
      verticalOffset: _resolvedVerticalOffset,
      preferBelow: preferBelow,
      excludeFromSemantics: excludeFromSemantics,
      decoration: _resolvedDecoration,
      textStyle: _resolvedTextStyle,
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

  // Pre-resolved resource values
  late final String? _resolvedTitle;

  TomCupertinoAlertDialog({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    this.title,
    this.titleText,
    this.content,
    this.actions = const [],
    this.scrollController,
    this.actionScrollController,
    this.insetAnimationCurve,
  }) {
    _resolvedTitle = titleText ?? (tomId != null ? TomCtr.textOrFail(basePath, 'title') : null);
  }

  @override
  Widget buildContent(BuildContext context) {
    final effectiveTitle =
        title ?? (_resolvedTitle != null ? Text(_resolvedTitle) : null);

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

  // Pre-resolved resource values
  late final String? _resolvedTitle;

  TomCupertinoActionSheet({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    this.title,
    this.titleText,
    this.message,
    this.actions = const [],
    this.messageScrollController,
    this.actionScrollController,
    this.cancelButton,
  }) {
    _resolvedTitle = titleText ?? (tomId != null ? TomCtr.textOrFail(basePath, 'title') : null);
  }

  @override
  Widget buildContent(BuildContext context) {
    final effectiveTitle =
        title ?? (_resolvedTitle != null ? Text(_resolvedTitle) : null);

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
    super.authorizer,
    super.uiStateController,
    required WidgetBuilder builder,
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
  }) : builder = InScopeBuilder(scope: scope).wrap1(builder);

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
    final wrappedBuilder = InScopeBuilder(scope: _findScopeFromContext(context)).wrap1(builder);
    return material.showDialog<T>(
      context: context,
      builder: wrappedBuilder,
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
    final wrappedBuilder = InScopeBuilder(scope: _findScopeFromContext(context)).wrap1(builder);
    return material.showModalBottomSheet<T>(
      context: context,
      builder: wrappedBuilder,
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

  /// Finds the nearest [TomScope] from the widget tree via [context].
  ///
  /// Checks the context's own widget first, then walks up ancestors.
  /// Falls back to [TomScope.current] if no Tom widget is found.
  static TomScope _findScopeFromContext(BuildContext context) {
    if (context is Element) {
      final scope = _extractScope(context.widget);
      if (scope != null) return scope;
    }
    TomScope? found;
    context.visitAncestorElements((element) {
      found = _extractScope(element.widget);
      return found == null;
    });
    return found ?? TomScope.current;
  }

  static TomScope? _extractScope(Widget widget) {
    if (widget is TomNodeBase) return widget.constructionScope;
    if (widget is TomStatefulWidget) return widget.constructionScope;
    return null;
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

  // Pre-resolved resource values
  late final String? _resolvedApplicationName;
  late final String? _resolvedApplicationVersion;
  late final String? _resolvedApplicationLegalese;

  TomAboutDialog({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    this.applicationName,
    this.applicationVersion,
    this.applicationIcon,
    this.applicationLegalese,
    this.children,
  }) {
    _resolvedApplicationName = applicationName ?? (tomId != null ? TomCtr.textOrFail(basePath, 'applicationName') : null);
    _resolvedApplicationVersion = applicationVersion ?? (tomId != null ? TomCtr.textOrFail(basePath, 'applicationVersion') : null);
    _resolvedApplicationLegalese = applicationLegalese ?? (tomId != null ? TomCtr.textOrFail(basePath, 'applicationLegalese') : null);
  }

  @override
  Widget buildContent(BuildContext context) {
    return AboutDialog(
      applicationName: _resolvedApplicationName,
      applicationVersion: _resolvedApplicationVersion,
      applicationIcon: applicationIcon,
      applicationLegalese: _resolvedApplicationLegalese,
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

  // Pre-resolved resource values
  late final bool _resolvedEnableHapticFeedback;

  TomCupertinoContextMenu({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required this.child,
    required this.actions,
    this.enableHapticFeedback,
  }) {
    _resolvedEnableHapticFeedback = enableHapticFeedback ?? TomCtr.boolVal(basePath, 'enableHapticFeedback') ?? false;
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoContextMenu(
      actions: actions,
      enableHapticFeedback: _resolvedEnableHapticFeedback,
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

  // Pre-resolved resource values
  late final TextInputType? _resolvedKeyboardType;
  late final String? _resolvedCancelText;
  late final String? _resolvedConfirmText;
  late final String? _resolvedHelpText;
  late final String? _resolvedErrorFormatText;
  late final String? _resolvedErrorInvalidText;
  late final String? _resolvedFieldHintText;
  late final String? _resolvedFieldLabelText;

  TomDatePickerDialog({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
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
  }) {
    _resolvedKeyboardType = keyboardType ?? _resolveTextInputType(TomCtr.textOrNull(basePath, 'keyboardType'));
    _resolvedCancelText = cancelText ?? TomCtr.textOrNull(basePath, 'cancel');
    _resolvedConfirmText = confirmText ?? TomCtr.textOrNull(basePath, 'confirm');
    _resolvedHelpText = helpText ?? TomCtr.textOrNull(basePath, 'help');
    _resolvedErrorFormatText = errorFormatText ?? TomCtr.textOrNull(basePath, 'errorFormat');
    _resolvedErrorInvalidText = errorInvalidText ?? TomCtr.textOrNull(basePath, 'errorInvalid');
    _resolvedFieldHintText = fieldHintText ?? TomCtr.textOrNull(basePath, 'fieldHint');
    _resolvedFieldLabelText = fieldLabelText ?? TomCtr.textOrNull(basePath, 'fieldLabel');
  }

  @override
  Widget buildContent(BuildContext context) {
    return DatePickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      currentDate: currentDate,
      initialEntryMode: initialEntryMode,
      selectableDayPredicate: selectableDayPredicate,
      cancelText: _resolvedCancelText,
      confirmText: _resolvedConfirmText,
      helpText: _resolvedHelpText,
      initialCalendarMode: initialCalendarMode,
      errorFormatText: _resolvedErrorFormatText,
      errorInvalidText: _resolvedErrorInvalidText,
      fieldHintText: _resolvedFieldHintText,
      fieldLabelText: _resolvedFieldLabelText,
      keyboardType: _resolvedKeyboardType,
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

  // Pre-resolved resource values
  late final TextInputType _resolvedKeyboardType;
  late final String? _resolvedHelpText;
  late final String? _resolvedCancelText;
  late final String? _resolvedConfirmText;
  late final String? _resolvedSaveText;
  late final String? _resolvedErrorFormatText;
  late final String? _resolvedErrorInvalidText;
  late final String? _resolvedErrorInvalidRangeText;
  late final String? _resolvedFieldStartHintText;
  late final String? _resolvedFieldEndHintText;
  late final String? _resolvedFieldStartLabelText;
  late final String? _resolvedFieldEndLabelText;

  TomDateRangePickerDialog({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
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
  }) {
    _resolvedKeyboardType = keyboardType ?? _resolveTextInputType(TomCtr.textOrNull(basePath, 'keyboardType')) ?? TextInputType.datetime;
    _resolvedHelpText = helpText ?? TomCtr.textOrNull(basePath, 'help');
    _resolvedCancelText = cancelText ?? TomCtr.textOrNull(basePath, 'cancel');
    _resolvedConfirmText = confirmText ?? TomCtr.textOrNull(basePath, 'confirm');
    _resolvedSaveText = saveText ?? TomCtr.textOrNull(basePath, 'save');
    _resolvedErrorFormatText = errorFormatText ?? TomCtr.textOrNull(basePath, 'errorFormat');
    _resolvedErrorInvalidText = errorInvalidText ?? TomCtr.textOrNull(basePath, 'errorInvalid');
    _resolvedErrorInvalidRangeText = errorInvalidRangeText ?? TomCtr.textOrNull(basePath, 'errorInvalidRange');
    _resolvedFieldStartHintText = fieldStartHintText ?? TomCtr.textOrNull(basePath, 'fieldStartHint');
    _resolvedFieldEndHintText = fieldEndHintText ?? TomCtr.textOrNull(basePath, 'fieldEndHint');
    _resolvedFieldStartLabelText = fieldStartLabelText ?? TomCtr.textOrNull(basePath, 'fieldStartLabel');
    _resolvedFieldEndLabelText = fieldEndLabelText ?? TomCtr.textOrNull(basePath, 'fieldEndLabel');
  }

  @override
  Widget buildContent(BuildContext context) {
    return DateRangePickerDialog(
      initialDateRange: initialDateRange,
      firstDate: firstDate,
      lastDate: lastDate,
      currentDate: currentDate,
      initialEntryMode: initialEntryMode,
      helpText: _resolvedHelpText,
      cancelText: _resolvedCancelText,
      confirmText: _resolvedConfirmText,
      saveText: _resolvedSaveText,
      errorFormatText: _resolvedErrorFormatText,
      errorInvalidText: _resolvedErrorInvalidText,
      errorInvalidRangeText: _resolvedErrorInvalidRangeText,
      fieldStartHintText: _resolvedFieldStartHintText,
      fieldEndHintText: _resolvedFieldEndHintText,
      fieldStartLabelText: _resolvedFieldStartLabelText,
      fieldEndLabelText: _resolvedFieldEndLabelText,
      keyboardType: _resolvedKeyboardType,
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

  // Pre-resolved resource values
  late final String? _resolvedCancelText;
  late final String? _resolvedConfirmText;
  late final String? _resolvedHelpText;
  late final String? _resolvedErrorInvalidText;
  late final String? _resolvedHourLabelText;
  late final String? _resolvedMinuteLabelText;

  TomTimePickerDialog({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required this.initialTime,
    this.cancelText,
    this.confirmText,
    this.helpText,
    this.errorInvalidText,
    this.hourLabelText,
    this.minuteLabelText,
    this.initialEntryMode = TimePickerEntryMode.dial,
    this.orientation,
    EntryModeChangeCallback? onEntryModeChanged,
  })  : onEntryModeChanged = InScopeBuilder(scope: scope).wrap1n(onEntryModeChanged) {
    _resolvedCancelText = cancelText ?? TomCtr.textOrNull(basePath, 'cancel');
    _resolvedConfirmText = confirmText ?? TomCtr.textOrNull(basePath, 'confirm');
    _resolvedHelpText = helpText ?? TomCtr.textOrNull(basePath, 'help');
    _resolvedErrorInvalidText = errorInvalidText ?? TomCtr.textOrNull(basePath, 'errorInvalid');
    _resolvedHourLabelText = hourLabelText ?? TomCtr.textOrNull(basePath, 'hourLabel');
    _resolvedMinuteLabelText = minuteLabelText ?? TomCtr.textOrNull(basePath, 'minuteLabel');
  }

  @override
  Widget buildContent(BuildContext context) {
    return TimePickerDialog(
      initialTime: initialTime,
      cancelText: _resolvedCancelText,
      confirmText: _resolvedConfirmText,
      helpText: _resolvedHelpText,
      errorInvalidText: _resolvedErrorInvalidText,
      hourLabelText: _resolvedHourLabelText,
      minuteLabelText: _resolvedMinuteLabelText,
      initialEntryMode: initialEntryMode,
      orientation: orientation,
      onEntryModeChanged: onEntryModeChanged,
    );
  }
}

BottomSheetDragEndHandler? _wrapDragEndHandler(
  TomScope? scope,
  BottomSheetDragEndHandler? handler,
) {
  if (handler == null) return null;
  final s = InScopeBuilder(scope: scope);
  return (DragEndDetails details, {required bool isClosing}) {
    s.wrap0(() => handler(details, isClosing: isClosing))();
  };
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

  // Pre-resolved resource values
  late final EdgeInsets? _resolvedPadding;

  TomSimpleDialogOption({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    VoidCallback? onPressed,
    this.padding,
    this.child,
  })  : onPressed = InScopeBuilder(scope: scope).wrap0n(onPressed) {
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
  }

  @override
  Widget buildContent(BuildContext context) {
    return SimpleDialogOption(
      onPressed: onPressed,
      padding: _resolvedPadding,
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

  // Pre-resolved resource values
  late final String? _resolvedApplicationName;
  late final String? _resolvedApplicationVersion;
  late final String? _resolvedApplicationLegalese;

  TomLicensePage({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    this.applicationName,
    this.applicationVersion,
    this.applicationIcon,
    this.applicationLegalese,
  }) {
    _resolvedApplicationName = applicationName ?? TomCtr.textOrNull(basePath, 'applicationName');
    _resolvedApplicationVersion = applicationVersion ?? TomCtr.textOrNull(basePath, 'applicationVersion');
    _resolvedApplicationLegalese = applicationLegalese ?? TomCtr.textOrNull(basePath, 'applicationLegalese');
  }

  @override
  Widget buildContent(BuildContext context) {
    return LicensePage(
      applicationName: _resolvedApplicationName,
      applicationVersion: _resolvedApplicationVersion,
      applicationIcon: applicationIcon,
      applicationLegalese: _resolvedApplicationLegalese,
    );
  }
}
