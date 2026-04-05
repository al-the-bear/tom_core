import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../resource_auth/tom_icons.dart';
import '../../widget_base/tom_family_base.dart';
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
  });

  @override
  Widget buildContent(BuildContext context) {
    // Resolve icon: use provided icon, or look up from resources
    final resolvedIcon = icon ?? _resolveIconFromResources(context);
    final resolvedSemanticLabel =
        semanticLabel ?? (tomId != null ? resolveResourceOrFail('alt') : null);

    // Phase 2: Resolve optional parameters from resources
    final resolvedSize =
        size ?? resolveDoubleOrNull('size');
    final resolvedColor =
        color ?? resolveColorOrNull('color');
    final resolvedFill =
        fill ?? resolveDoubleOrNull('fill');
    final resolvedWeight =
        weight ?? resolveDoubleOrNull('weight');
    final resolvedGrade =
        grade ?? resolveDoubleOrNull('grade');
    final resolvedOpticalSize =
        opticalSize ?? resolveDoubleOrNull('opticalSize');

    return Icon(
      resolvedIcon,
      size: resolvedSize,
      fill: resolvedFill,
      weight: resolvedWeight,
      grade: resolvedGrade,
      opticalSize: resolvedOpticalSize,
      color: resolvedColor,
      shadows: shadows,
      semanticLabel: resolvedSemanticLabel,
      textDirection: textDirection,
      applyTextScaling: applyTextScaling,
    );
  }

  /// Resolves icon from resources + icon provider.
  ///
  /// Returns `null` if tomId is not set or icon cannot be resolved.
  IconData? _resolveIconFromResources(BuildContext context) {
    if (tomId == null) return null;
    // Get icon name from resources (e.g., "save", "delete")
    final iconName = resolveResourceOrFail('icon');
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
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedSemanticLabel =
        semanticLabel ?? (tomId != null ? resolveResourceOrFail('alt') : null);

    // Phase 2: Resolve optional parameters from resources
    final resolvedWidth =
        width ?? resolveDoubleOrNull('width');
    final resolvedHeight =
        height ?? resolveDoubleOrNull('height');
    final resolvedColor =
        color ?? resolveColorOrNull('color');
    final resolvedAlignment =
        _resolveAlignment('alignment') ?? alignment;
    final resolvedMatchTextDirection =
        resolveBoolOrNull('matchTextDirection') ?? matchTextDirection;
    final resolvedGaplessPlayback =
        resolveBoolOrNull('gaplessPlayback') ?? gaplessPlayback;
    final resolvedIsAntiAlias =
        resolveBoolOrNull('isAntiAlias') ?? isAntiAlias;

    return Image(
      image: imageProvider,
      width: resolvedWidth,
      height: resolvedHeight,
      color: resolvedColor,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: resolvedAlignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: resolvedMatchTextDirection,
      gaplessPlayback: resolvedGaplessPlayback,
      isAntiAlias: resolvedIsAntiAlias,
      filterQuality: filterQuality,
      semanticLabel: resolvedSemanticLabel,
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
    this.onBackgroundImageError,
    this.onForegroundImageError,
    this.radius,
    this.minRadius,
    this.maxRadius,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedForegroundColor =
        foregroundColor ?? resolveColorOrNull('foregroundColor');
    final resolvedRadius =
        radius ?? resolveDoubleOrNull('radius');
    final resolvedMinRadius =
        minRadius ?? resolveDoubleOrNull('minRadius');
    final resolvedMaxRadius =
        maxRadius ?? resolveDoubleOrNull('maxRadius');

    return CircleAvatar(
      backgroundColor: resolvedBackgroundColor,
      foregroundColor: resolvedForegroundColor,
      backgroundImage: backgroundImage,
      foregroundImage: foregroundImage,
      onBackgroundImageError: onBackgroundImageError,
      onForegroundImageError: onForegroundImageError,
      radius: resolvedRadius,
      minRadius: resolvedMinRadius,
      maxRadius: resolvedMaxRadius,
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
    this.placeholderErrorBuilder,
    this.imageErrorBuilder,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedSemanticLabel = imageSemanticLabel ??
        (tomId != null ? resolveResourceOrFail('alt') : null);

    // Phase 2: Resolve optional parameters from resources
    final resolvedWidth =
        width ?? resolveDoubleOrNull('width');
    final resolvedHeight =
        height ?? resolveDoubleOrNull('height');
    final resolvedPlaceholderColor =
        placeholderColor ?? resolveColorOrNull('placeholderColor');
    final resolvedAlignment =
        _resolveAlignment('alignment') ?? alignment;
    final resolvedMatchTextDirection =
        resolveBoolOrNull('matchTextDirection') ?? matchTextDirection;
    final resolvedExcludeFromSemantics =
        resolveBoolOrNull('excludeFromSemantics') ?? excludeFromSemantics;

    return FadeInImage(
      placeholder: placeholder,
      image: image,
      fadeOutDuration: fadeOutDuration,
      fadeOutCurve: fadeOutCurve,
      fadeInDuration: fadeInDuration,
      fadeInCurve: fadeInCurve,
      width: resolvedWidth,
      height: resolvedHeight,
      fit: fit,
      placeholderFit: placeholderFit,
      alignment: resolvedAlignment,
      repeat: repeat,
      matchTextDirection: resolvedMatchTextDirection,
      excludeFromSemantics: resolvedExcludeFromSemantics,
      imageSemanticLabel: resolvedSemanticLabel,
      placeholderColor: resolvedPlaceholderColor,
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

  TomImageIcon({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.image,
    this.size,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedSemanticLabel = semanticLabel ??
        (tomId != null ? resolveResourceOrFail('semanticLabel') : null);

    // Phase 2: Resolve optional parameters from resources
    final resolvedSize =
        size ?? resolveDoubleOrNull('size');
    final resolvedColor =
        color ?? resolveColorOrNull('color');

    return ImageIcon(
      image,
      size: resolvedSize,
      color: resolvedColor,
      semanticLabel: resolvedSemanticLabel,
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
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding');
    final resolvedAlignment =
        _resolveAlignment('alignment') ?? alignment;
    final resolvedWidth =
        width ?? resolveDoubleOrNull('width');
    final resolvedHeight =
        height ?? resolveDoubleOrNull('height');

    return Ink.image(
      padding: resolvedPadding,
      image: image,
      colorFilter: colorFilter,
      fit: fit,
      alignment: resolvedAlignment,
      centerSlice: centerSlice,
      repeat: repeat,
      width: resolvedWidth,
      height: resolvedHeight,
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
    this.frameBuilder,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedSemanticLabel = semanticLabel ??
        (tomId != null ? resolveResourceOrFail('semanticLabel') : null);

    // Phase 2: Resolve optional parameters from resources
    final resolvedSrc =
        resolveResourceOrNull('src') ?? src;
    final resolvedScale =
        resolveDoubleOrNull('scale') ?? scale;
    final resolvedWidth =
        width ?? resolveDoubleOrNull('width');
    final resolvedHeight =
        height ?? resolveDoubleOrNull('height');
    final resolvedAlignment =
        _resolveAlignment('alignment') ?? alignment;
    final resolvedMatchTextDirection =
        resolveBoolOrNull('matchTextDirection') ?? matchTextDirection;
    final resolvedGaplessPlayback =
        resolveBoolOrNull('gaplessPlayback') ?? gaplessPlayback;
    final resolvedColor =
        color ?? resolveColorOrNull('color');
    final resolvedExcludeFromSemantics =
        resolveBoolOrNull('excludeFromSemantics') ?? excludeFromSemantics;

    return Image.network(
      resolvedSrc,
      scale: resolvedScale,
      headers: headers,
      width: resolvedWidth,
      height: resolvedHeight,
      fit: fit,
      alignment: resolvedAlignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: resolvedMatchTextDirection,
      gaplessPlayback: resolvedGaplessPlayback,
      filterQuality: filterQuality,
      isAntiAlias: isAntiAlias,
      color: resolvedColor,
      colorBlendMode: colorBlendMode,
      semanticLabel: resolvedSemanticLabel,
      excludeFromSemantics: resolvedExcludeFromSemantics,
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
    this.frameBuilder,
    this.errorBuilder,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedSemanticLabel = semanticLabel ??
        (tomId != null ? resolveResourceOrFail('semanticLabel') : null);

    // Phase 2: Resolve optional parameters from resources
    final resolvedWidth =
        width ?? resolveDoubleOrNull('width');
    final resolvedHeight =
        height ?? resolveDoubleOrNull('height');
    final resolvedColor =
        color ?? resolveColorOrNull('color');
    final resolvedCacheWidth =
        cacheWidth ?? resolveIntOrNull('cacheWidth');
    final resolvedCacheHeight =
        cacheHeight ?? resolveIntOrNull('cacheHeight');

    return Image.asset(
      name,
      bundle: bundle,
      package: package,
      width: resolvedWidth,
      height: resolvedHeight,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      filterQuality: filterQuality,
      isAntiAlias: isAntiAlias,
      color: resolvedColor,
      colorBlendMode: colorBlendMode,
      semanticLabel: resolvedSemanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      cacheWidth: resolvedCacheWidth,
      cacheHeight: resolvedCacheHeight,
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
    this.frameBuilder,
    this.errorBuilder,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedSemanticLabel = semanticLabel ??
        (tomId != null ? resolveResourceOrFail('semanticLabel') : null);

    // Phase 2: Resolve optional parameters from resources
    final resolvedWidth =
        width ?? resolveDoubleOrNull('width');
    final resolvedHeight =
        height ?? resolveDoubleOrNull('height');
    final resolvedColor =
        color ?? resolveColorOrNull('color');

    return Image(
      image: FileImage(File(filePath), scale: scale),
      width: resolvedWidth,
      height: resolvedHeight,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      filterQuality: filterQuality,
      isAntiAlias: isAntiAlias,
      color: resolvedColor,
      colorBlendMode: colorBlendMode,
      semanticLabel: resolvedSemanticLabel,
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
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedSemanticLabel =
        semanticLabel ?? resolveResourceOrNull('semanticLabel');

    // Phase 2: Resolve optional parameters from resources
    final resolvedColor =
        color ?? resolveColorOrNull('color');
    final resolvedSize =
        size ?? resolveDoubleOrNull('size');

    return AnimatedIcon(
      icon: icon,
      progress: progress,
      color: resolvedColor,
      size: resolvedSize,
      semanticLabel: resolvedSemanticLabel,
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

  TomImageFiltered({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.imageFilter,
    this.enabled,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedEnabled = enabled ?? resolveBoolOrNull('enabled') ?? true;

    return ImageFiltered(
      imageFilter: imageFilter,
      enabled: resolvedEnabled,
      child: child,
    );
  }
}
