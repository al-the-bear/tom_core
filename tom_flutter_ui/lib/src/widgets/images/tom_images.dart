import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../resource_auth/tom_icons.dart';
import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_construction_helpers.dart';
import '../../widget_base/tom_style_resolvers.dart';

/// Tom wrapper for [Icon].
///
/// Adds ID, group, authorization, and resource resolution for icon and alt.
///
/// Drop-in replacement for Flutter's [Icon] widget:
/// ```dart
/// TomIcon(icon: Icons.save)           // Explicit icon
/// TomIcon(icon: Icons.save, size: 24) // With size
/// ```
///
/// When icon is not provided, resolves via resource lookup:
/// 1. Gets icon name from resources using suffix 'icon'
/// 2. Looks up [IconData] from [TomUIIcons] provider
///
/// Example resource entry:
/// ```yaml
/// w-saveButton.icon: "save"
/// w-saveButton.alt: "Save the document"
/// ```
class TomIcon extends TomImageBase {
  /// The icon to display.
  final IconData? icon;
  final double? size;
  final double? fill;
  final double? weight;
  final double? grade;
  final double? opticalSize;
  final Color? color;
  final List<Shadow>? shadows;
  final String? semanticLabel;
  final TextDirection? textDirection;
  final bool? applyTextScaling;

  /// Creates a TomIcon widget.
  ///
  /// Use [icon] for explicit icon, or omit for resource resolution:
  /// ```dart
  /// TomIcon(icon: Icons.save)          // Explicit icon
  /// TomIcon(tomId: 'app.saveBtn')      // Resolves from resources
  /// ```
  // Pre-resolved resource values
  late final IconData? _resolvedIcon;
  late final String? _resolvedSemanticLabel;
  late final double? _resolvedSize;
  late final Color? _resolvedColor;
  late final double? _resolvedFill;
  late final double? _resolvedWeight;
  late final double? _resolvedGrade;
  late final double? _resolvedOpticalSize;

  TomIcon({
    this.icon,
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.size,
    this.fill,
    this.weight,
    this.grade,
    this.opticalSize,
    this.color,
    this.shadows,
    this.semanticLabel,
    this.textDirection,
    this.applyTextScaling,
  }) {
    _resolvedIcon = icon ?? _resolveIconFromResources();
    _resolvedSemanticLabel = semanticLabel ?? (tomId != null ? TomCtr.textOrFail(basePath, 'alt') : null);
    _resolvedSize = size ?? TomCtr.doubleVal(basePath, 'size');
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
    _resolvedFill = fill ?? TomCtr.doubleVal(basePath, 'fill');
    _resolvedWeight = weight ?? TomCtr.doubleVal(basePath, 'weight');
    _resolvedGrade = grade ?? TomCtr.doubleVal(basePath, 'grade');
    _resolvedOpticalSize = opticalSize ?? TomCtr.doubleVal(basePath, 'opticalSize');
  }

  @override
  Widget buildContent(BuildContext context) {
    return Icon(
      _resolvedIcon,
      size: _resolvedSize,
      fill: _resolvedFill,
      weight: _resolvedWeight,
      grade: _resolvedGrade,
      opticalSize: _resolvedOpticalSize,
      color: _resolvedColor,
      shadows: shadows,
      semanticLabel: _resolvedSemanticLabel,
      textDirection: textDirection,
      applyTextScaling: applyTextScaling,
    );
  }

  /// Resolves icon from resources + icon provider.
  ///
  /// Returns `null` if tomId is not set or icon cannot be resolved.
  IconData? _resolveIconFromResources() {
    if (tomId == null) return null;
    // Get icon name from resources (e.g., "save", "delete")
    final iconName = TomCtr.textOrFail(basePath, 'icon');
    // Skip if it returns the key itself (no resource found)
    if (iconName.endsWith('.icon')) return null;
    // Look up IconData from icon provider
    return TomUIIcons.resolveIcon(iconName);
  }
}

/// Tom wrapper for [Image].
///
/// Wraps [Image] with ID, group, authorization, and resource-based semantics.
/// Accepts an [ImageProvider] (use [Image.network], [Image.asset], etc.
/// constructors via the [imageProvider] parameter).
class TomImage extends TomImageBase {
  final ImageProvider imageProvider;
  final double? width;
  final double? height;
  final Color? color;
  final BlendMode? colorBlendMode;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final ImageRepeat repeat;
  final Rect? centerSlice;
  final bool matchTextDirection;
  final bool gaplessPlayback;
  final bool isAntiAlias;
  final FilterQuality filterQuality;
  final String? semanticLabel;

  // Pre-resolved resource values
  late final String? _resolvedSemanticLabel;
  late final double? _resolvedWidth;
  late final double? _resolvedHeight;
  late final Color? _resolvedColor;
  late final AlignmentGeometry _resolvedAlignment;
  late final bool _resolvedMatchTextDirection;
  late final bool _resolvedGaplessPlayback;
  late final bool _resolvedIsAntiAlias;

  TomImage({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.imageProvider,
    this.width,
    this.height,
    this.color,
    this.colorBlendMode,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.gaplessPlayback = false,
    this.isAntiAlias = false,
    this.filterQuality = FilterQuality.medium,
    this.semanticLabel,
  }) {
    _resolvedSemanticLabel = semanticLabel ?? (tomId != null ? TomCtr.textOrFail(basePath, 'alt') : null);
    _resolvedWidth = width ?? TomCtr.doubleVal(basePath, 'width');
    _resolvedHeight = height ?? TomCtr.doubleVal(basePath, 'height');
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
    _resolvedAlignment = _resolveAlignment('alignment') ?? alignment;
    _resolvedMatchTextDirection = TomCtr.boolVal(basePath, 'matchTextDirection') ?? matchTextDirection;
    _resolvedGaplessPlayback = TomCtr.boolVal(basePath, 'gaplessPlayback') ?? gaplessPlayback;
    _resolvedIsAntiAlias = TomCtr.boolVal(basePath, 'isAntiAlias') ?? isAntiAlias;
  }

  @override
  Widget buildContent(BuildContext context) {
    return Image(
      image: imageProvider,
      width: _resolvedWidth,
      height: _resolvedHeight,
      color: _resolvedColor,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: _resolvedAlignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: _resolvedMatchTextDirection,
      gaplessPlayback: _resolvedGaplessPlayback,
      isAntiAlias: _resolvedIsAntiAlias,
      filterQuality: filterQuality,
      semanticLabel: _resolvedSemanticLabel,
    );
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
  }
}

/// Tom wrapper for [CircleAvatar].
///
/// Adds ID, group, authorization, and resource resolution for tooltip.
class TomCircleAvatar extends TomImageBase {
  final Widget? child;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final ImageProvider? backgroundImage;
  final ImageProvider? foregroundImage;
  final ImageErrorListener? onBackgroundImageError;
  final ImageErrorListener? onForegroundImageError;
  final double? radius;
  final double? minRadius;
  final double? maxRadius;

  // Pre-resolved resource values
  late final Color? _resolvedBackgroundColor;
  late final Color? _resolvedForegroundColor;
  late final double? _resolvedRadius;
  late final double? _resolvedMinRadius;
  late final double? _resolvedMaxRadius;

  TomCircleAvatar({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.child,
    this.backgroundColor,
    this.foregroundColor,
    this.backgroundImage,
    this.foregroundImage,
    ImageErrorListener? onBackgroundImageError,
    ImageErrorListener? onForegroundImageError,
    this.radius,
    this.minRadius,
    this.maxRadius,
  })  : onBackgroundImageError = InScopeBuilder(scope: scope).wrap2n(onBackgroundImageError),
        onForegroundImageError = InScopeBuilder(scope: scope).wrap2n(onForegroundImageError) {
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedForegroundColor = foregroundColor ?? TomCtr.color(basePath, 'foregroundColor');
    _resolvedRadius = radius ?? TomCtr.doubleVal(basePath, 'radius');
    _resolvedMinRadius = minRadius ?? TomCtr.doubleVal(basePath, 'minRadius');
    _resolvedMaxRadius = maxRadius ?? TomCtr.doubleVal(basePath, 'maxRadius');
  }

  @override
  Widget buildContent(BuildContext context) {
    return CircleAvatar(
      backgroundColor: _resolvedBackgroundColor,
      foregroundColor: _resolvedForegroundColor,
      backgroundImage: backgroundImage,
      foregroundImage: foregroundImage,
      onBackgroundImageError: onBackgroundImageError,
      onForegroundImageError: onForegroundImageError,
      radius: _resolvedRadius,
      minRadius: _resolvedMinRadius,
      maxRadius: _resolvedMaxRadius,
      child: child,
    );
  }
}

/// Tom wrapper for [FadeInImage].
///
/// Adds ID, group, authorization, and resource resolution for alt text.
class TomFadeInImage extends TomImageBase {
  final ImageProvider placeholder;
  final ImageProvider image;
  final Duration fadeOutDuration;
  final Curve fadeOutCurve;
  final Duration fadeInDuration;
  final Curve fadeInCurve;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final BoxFit? placeholderFit;
  final FilterQuality filterQuality;
  final AlignmentGeometry alignment;
  final ImageRepeat repeat;
  final bool matchTextDirection;
  final bool excludeFromSemantics;
  final String? imageSemanticLabel;
  final Color? placeholderColor;
  final BlendMode? placeholderColorBlendMode;
  final ImageErrorWidgetBuilder? placeholderErrorBuilder;
  final ImageErrorWidgetBuilder? imageErrorBuilder;

  // Pre-resolved resource values
  late final String? _resolvedSemanticLabel;
  late final double? _resolvedWidth;
  late final double? _resolvedHeight;
  late final Color? _resolvedPlaceholderColor;
  late final AlignmentGeometry _resolvedAlignment;
  late final bool _resolvedMatchTextDirection;
  late final bool _resolvedExcludeFromSemantics;

  TomFadeInImage({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.placeholder,
    required this.image,
    this.fadeOutDuration = const Duration(milliseconds: 300),
    this.fadeOutCurve = Curves.easeOut,
    this.fadeInDuration = const Duration(milliseconds: 700),
    this.fadeInCurve = Curves.easeIn,
    this.width,
    this.height,
    this.fit,
    this.placeholderFit,
    this.filterQuality = FilterQuality.low,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.matchTextDirection = false,
    this.excludeFromSemantics = false,
    this.imageSemanticLabel,
    this.placeholderColor,
    this.placeholderColorBlendMode,
    ImageErrorWidgetBuilder? placeholderErrorBuilder,
    ImageErrorWidgetBuilder? imageErrorBuilder,
  }) : placeholderErrorBuilder = placeholderErrorBuilder != null ? InScopeBuilder(scope: scope).wrap3(placeholderErrorBuilder) : null,
       imageErrorBuilder = imageErrorBuilder != null ? InScopeBuilder(scope: scope).wrap3(imageErrorBuilder) : null {
    _resolvedSemanticLabel = imageSemanticLabel ?? (tomId != null ? TomCtr.textOrFail(basePath, 'alt') : null);
    _resolvedWidth = width ?? TomCtr.doubleVal(basePath, 'width');
    _resolvedHeight = height ?? TomCtr.doubleVal(basePath, 'height');
    _resolvedPlaceholderColor = placeholderColor ?? TomCtr.color(basePath, 'placeholderColor');
    _resolvedAlignment = _resolveAlignment('alignment') ?? alignment;
    _resolvedMatchTextDirection = TomCtr.boolVal(basePath, 'matchTextDirection') ?? matchTextDirection;
    _resolvedExcludeFromSemantics = TomCtr.boolVal(basePath, 'excludeFromSemantics') ?? excludeFromSemantics;
  }

  @override
  Widget buildContent(BuildContext context) {
    return FadeInImage(
      placeholder: placeholder,
      image: image,
      fadeOutDuration: fadeOutDuration,
      fadeOutCurve: fadeOutCurve,
      fadeInDuration: fadeInDuration,
      fadeInCurve: fadeInCurve,
      width: _resolvedWidth,
      height: _resolvedHeight,
      fit: fit,
      placeholderFit: placeholderFit,
      alignment: _resolvedAlignment,
      repeat: repeat,
      matchTextDirection: _resolvedMatchTextDirection,
      excludeFromSemantics: _resolvedExcludeFromSemantics,
      imageSemanticLabel: _resolvedSemanticLabel,
      placeholderColor: _resolvedPlaceholderColor,
      placeholderColorBlendMode: placeholderColorBlendMode,
      placeholderErrorBuilder: placeholderErrorBuilder,
      imageErrorBuilder: imageErrorBuilder,
    );
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
  }
}

/// Tom wrapper for [ImageIcon].
///
/// Adds ID, group, authorization, and resource resolution.
class TomImageIcon extends TomImageBase {
  final ImageProvider? image;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  // Pre-resolved resource values
  late final String? _resolvedSemanticLabel;
  late final double? _resolvedSize;
  late final Color? _resolvedColor;

  TomImageIcon({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.image,
    this.size,
    this.color,
    this.semanticLabel,
  }) {
    _resolvedSemanticLabel = semanticLabel ?? (tomId != null ? TomCtr.textOrFail(basePath, 'semanticLabel') : null);
    _resolvedSize = size ?? TomCtr.doubleVal(basePath, 'size');
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
  }

  @override
  Widget buildContent(BuildContext context) {
    return ImageIcon(
      image,
      size: _resolvedSize,
      color: _resolvedColor,
      semanticLabel: _resolvedSemanticLabel,
    );
  }
}

/// Tom wrapper for [Ink.image].
///
/// Paints an image on a [Material] widget with ink splash support.
/// Adds ID, group, authorization, and resource resolution.
class TomInkImage extends TomImageBase {
  final EdgeInsetsGeometry? padding;
  final ImageProvider image;
  final ColorFilter? colorFilter;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final Rect? centerSlice;
  final ImageRepeat repeat;
  final double? width;
  final double? height;
  final Widget? child;

  // Pre-resolved resource values
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final AlignmentGeometry _resolvedAlignment;
  late final double? _resolvedWidth;
  late final double? _resolvedHeight;

  TomInkImage({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.padding,
    required this.image,
    this.colorFilter,
    this.fit,
    this.alignment = Alignment.center,
    this.centerSlice,
    this.repeat = ImageRepeat.noRepeat,
    this.width,
    this.height,
    this.child,
  }) {
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
    _resolvedAlignment = _resolveAlignment('alignment') ?? alignment;
    _resolvedWidth = width ?? TomCtr.doubleVal(basePath, 'width');
    _resolvedHeight = height ?? TomCtr.doubleVal(basePath, 'height');
  }

  @override
  Widget buildContent(BuildContext context) {
    return Ink.image(
      padding: _resolvedPadding,
      image: image,
      colorFilter: colorFilter,
      fit: fit,
      alignment: _resolvedAlignment,
      centerSlice: centerSlice,
      repeat: repeat,
      width: _resolvedWidth,
      height: _resolvedHeight,
      child: child,
    );
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
  }
}

/// Tom wrapper for [Image] that uses [NetworkImage] as its provider.
///
/// Convenience widget for displaying a network image.
/// Adds ID, group, authorization, and resource resolution.
class TomNetworkImage extends TomImageBase {
  final String src;
  final double scale;
  final Map<String, String>? headers;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final ImageRepeat repeat;
  final Rect? centerSlice;
  final bool matchTextDirection;
  final bool gaplessPlayback;
  final FilterQuality filterQuality;
  final bool isAntiAlias;
  final Color? color;
  final BlendMode? colorBlendMode;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final ImageFrameBuilder? frameBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  // Pre-resolved resource values
  late final String? _resolvedSemanticLabel;
  late final String _resolvedSrc;
  late final double _resolvedScale;
  late final double? _resolvedWidth;
  late final double? _resolvedHeight;
  late final AlignmentGeometry _resolvedAlignment;
  late final bool _resolvedMatchTextDirection;
  late final bool _resolvedGaplessPlayback;
  late final Color? _resolvedColor;
  late final bool _resolvedExcludeFromSemantics;

  TomNetworkImage({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.src,
    this.scale = 1.0,
    this.headers,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.gaplessPlayback = false,
    this.filterQuality = FilterQuality.low,
    this.isAntiAlias = false,
    this.color,
    this.colorBlendMode,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    ImageFrameBuilder? frameBuilder,
    ImageLoadingBuilder? loadingBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
  }) : frameBuilder = frameBuilder != null ? InScopeBuilder(scope: scope).wrap4(frameBuilder) : null,
       loadingBuilder = loadingBuilder != null ? InScopeBuilder(scope: scope).wrap3(loadingBuilder) : null,
       errorBuilder = errorBuilder != null ? InScopeBuilder(scope: scope).wrap3(errorBuilder) : null {
    _resolvedSemanticLabel = semanticLabel ?? (tomId != null ? TomCtr.textOrFail(basePath, 'semanticLabel') : null);
    _resolvedSrc = TomCtr.textOrNull(basePath, 'src') ?? src;
    _resolvedScale = TomCtr.doubleVal(basePath, 'scale') ?? scale;
    _resolvedWidth = width ?? TomCtr.doubleVal(basePath, 'width');
    _resolvedHeight = height ?? TomCtr.doubleVal(basePath, 'height');
    _resolvedAlignment = _resolveAlignment('alignment') ?? alignment;
    _resolvedMatchTextDirection = TomCtr.boolVal(basePath, 'matchTextDirection') ?? matchTextDirection;
    _resolvedGaplessPlayback = TomCtr.boolVal(basePath, 'gaplessPlayback') ?? gaplessPlayback;
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
    _resolvedExcludeFromSemantics = TomCtr.boolVal(basePath, 'excludeFromSemantics') ?? excludeFromSemantics;
  }

  @override
  Widget buildContent(BuildContext context) {
    return Image.network(
      _resolvedSrc,
      scale: _resolvedScale,
      headers: headers,
      width: _resolvedWidth,
      height: _resolvedHeight,
      fit: fit,
      alignment: _resolvedAlignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: _resolvedMatchTextDirection,
      gaplessPlayback: _resolvedGaplessPlayback,
      filterQuality: filterQuality,
      isAntiAlias: isAntiAlias,
      color: _resolvedColor,
      colorBlendMode: colorBlendMode,
      semanticLabel: _resolvedSemanticLabel,
      excludeFromSemantics: _resolvedExcludeFromSemantics,
      frameBuilder: frameBuilder,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
    );
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
  }
}

/// Tom wrapper for [Image] that uses [AssetImage] as its provider.
///
/// Convenience widget for displaying an asset image.
/// Adds ID, group, authorization, and resource resolution.
class TomAssetImage extends TomImageBase {
  final String name;
  final AssetBundle? bundle;
  final String? package;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final ImageRepeat repeat;
  final Rect? centerSlice;
  final bool matchTextDirection;
  final bool gaplessPlayback;
  final FilterQuality filterQuality;
  final bool isAntiAlias;
  final Color? color;
  final BlendMode? colorBlendMode;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final ImageFrameBuilder? frameBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;
  final int? cacheWidth;
  final int? cacheHeight;

  // Pre-resolved resource values
  late final String? _resolvedSemanticLabel;
  late final double? _resolvedWidth;
  late final double? _resolvedHeight;
  late final Color? _resolvedColor;
  late final int? _resolvedCacheWidth;
  late final int? _resolvedCacheHeight;

  TomAssetImage({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.name,
    this.bundle,
    this.package,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.gaplessPlayback = false,
    this.filterQuality = FilterQuality.low,
    this.isAntiAlias = false,
    this.color,
    this.colorBlendMode,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    this.cacheWidth,
    this.cacheHeight,
  }) : frameBuilder = frameBuilder != null ? InScopeBuilder(scope: scope).wrap4(frameBuilder) : null,
       errorBuilder = errorBuilder != null ? InScopeBuilder(scope: scope).wrap3(errorBuilder) : null {
    _resolvedSemanticLabel = semanticLabel ?? (tomId != null ? TomCtr.textOrFail(basePath, 'semanticLabel') : null);
    _resolvedWidth = width ?? TomCtr.doubleVal(basePath, 'width');
    _resolvedHeight = height ?? TomCtr.doubleVal(basePath, 'height');
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
    _resolvedCacheWidth = cacheWidth ?? TomCtr.intVal(basePath, 'cacheWidth');
    _resolvedCacheHeight = cacheHeight ?? TomCtr.intVal(basePath, 'cacheHeight');
  }

  @override
  Widget buildContent(BuildContext context) {
    return Image.asset(
      name,
      bundle: bundle,
      package: package,
      width: _resolvedWidth,
      height: _resolvedHeight,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      filterQuality: filterQuality,
      isAntiAlias: isAntiAlias,
      color: _resolvedColor,
      colorBlendMode: colorBlendMode,
      semanticLabel: _resolvedSemanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      cacheWidth: _resolvedCacheWidth,
      cacheHeight: _resolvedCacheHeight,
    );
  }
}

/// Tom wrapper for [Image] that uses [FileImage] as its provider.
///
/// Convenience widget for displaying a file-based image.
/// Adds ID, group, authorization, and resource resolution.
class TomFileImage extends TomImageBase {
  final String filePath;
  final double scale;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final ImageRepeat repeat;
  final Rect? centerSlice;
  final bool matchTextDirection;
  final bool gaplessPlayback;
  final FilterQuality filterQuality;
  final bool isAntiAlias;
  final Color? color;
  final BlendMode? colorBlendMode;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final ImageFrameBuilder? frameBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  // Pre-resolved resource values
  late final String? _resolvedSemanticLabel;
  late final double? _resolvedWidth;
  late final double? _resolvedHeight;
  late final Color? _resolvedColor;

  TomFileImage({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.filePath,
    this.scale = 1.0,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.gaplessPlayback = false,
    this.filterQuality = FilterQuality.low,
    this.isAntiAlias = false,
    this.color,
    this.colorBlendMode,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
  }) : frameBuilder = frameBuilder != null ? InScopeBuilder(scope: scope).wrap4(frameBuilder) : null,
       errorBuilder = errorBuilder != null ? InScopeBuilder(scope: scope).wrap3(errorBuilder) : null {
    _resolvedSemanticLabel = semanticLabel ?? (tomId != null ? TomCtr.textOrFail(basePath, 'semanticLabel') : null);
    _resolvedWidth = width ?? TomCtr.doubleVal(basePath, 'width');
    _resolvedHeight = height ?? TomCtr.doubleVal(basePath, 'height');
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
  }

  @override
  Widget buildContent(BuildContext context) {
    return Image(
      image: FileImage(File(filePath), scale: scale),
      width: _resolvedWidth,
      height: _resolvedHeight,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      filterQuality: filterQuality,
      isAntiAlias: isAntiAlias,
      color: _resolvedColor,
      colorBlendMode: colorBlendMode,
      semanticLabel: _resolvedSemanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
    );
  }
}

// ============================================================================
// Section II: Extended Image Widgets
// ============================================================================

/// Tom wrapper for [AnimatedIcon].
///
/// Animated material icon transitions. Auth on icon visibility.
class TomAnimatedIcon extends TomImageBase {
  final AnimatedIconData icon;
  final Animation<double> progress;
  final Color? color;
  final double? size;
  final String? semanticLabel;
  final TextDirection? textDirection;

  // Pre-resolved resource values
  late final String? _resolvedSemanticLabel;
  late final Color? _resolvedColor;
  late final double? _resolvedSize;

  TomAnimatedIcon({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.icon,
    required this.progress,
    this.color,
    this.size,
    this.semanticLabel,
    this.textDirection,
  }) {
    _resolvedSemanticLabel = semanticLabel ?? TomCtr.textOrNull(basePath, 'semanticLabel');
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
    _resolvedSize = size ?? TomCtr.doubleVal(basePath, 'size');
  }

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedIcon(
      icon: icon,
      progress: progress,
      color: _resolvedColor,
      size: _resolvedSize,
      semanticLabel: _resolvedSemanticLabel,
      textDirection: textDirection,
    );
  }
}

/// Tom wrapper for [ImageFiltered].
///
/// Applies ImageFilter (blur, matrix) to child. Auth on filtered content.
class TomImageFiltered extends TomImageBase {
  final ImageFilter imageFilter;
  final bool? enabled;
  final Widget? child;

  // Pre-resolved resource values
  late final bool _resolvedEnabled;

  TomImageFiltered({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.imageFilter,
    this.enabled,
    this.child,
  }) {
    _resolvedEnabled = enabled ?? TomCtr.boolVal(basePath, 'enabled') ?? true;
  }

  @override
  Widget buildContent(BuildContext context) {
    return ImageFiltered(
      imageFilter: imageFilter,
      enabled: _resolvedEnabled,
      child: child,
    );
  }
}
