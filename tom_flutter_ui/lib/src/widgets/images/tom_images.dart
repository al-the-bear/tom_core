import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../widget_base/tom_family_base.dart';

/// Tom wrapper for [Icon].
///
/// Adds ID, group, authorization, and resource resolution for tooltip/alt.
class TomIcon extends TomImageBase {
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

  const TomIcon({
    super.key,
    super.tomId,
    super.tomGroup,
    this.icon,
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
    final resolvedSemanticLabel =
        semanticLabel ?? (tomId != null ? resolveResource(context, 'alt') : null);

    return Icon(
      icon,
      size: size,
      fill: fill,
      weight: weight,
      grade: grade,
      opticalSize: opticalSize,
      color: color,
      shadows: shadows,
      semanticLabel: resolvedSemanticLabel,
      textDirection: textDirection,
      applyTextScaling: applyTextScaling,
    );
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

  const TomImage({
    super.key,
    super.tomId,
    super.tomGroup,
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
        semanticLabel ?? (tomId != null ? resolveResource(context, 'alt') : null);

    return Image(
      image: imageProvider,
      width: width,
      height: height,
      color: color,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      filterQuality: filterQuality,
      semanticLabel: resolvedSemanticLabel,
    );
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

  const TomCircleAvatar({
    super.key,
    super.tomId,
    super.tomGroup,
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
    return CircleAvatar(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      backgroundImage: backgroundImage,
      foregroundImage: foregroundImage,
      onBackgroundImageError: onBackgroundImageError,
      onForegroundImageError: onForegroundImageError,
      radius: radius,
      minRadius: minRadius,
      maxRadius: maxRadius,
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

  const TomFadeInImage({
    super.key,
    super.tomId,
    super.tomGroup,
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
        (tomId != null ? resolveResource(context, 'alt') : null);

    return FadeInImage(
      placeholder: placeholder,
      image: image,
      fadeOutDuration: fadeOutDuration,
      fadeOutCurve: fadeOutCurve,
      fadeInDuration: fadeInDuration,
      fadeInCurve: fadeInCurve,
      width: width,
      height: height,
      fit: fit,
      placeholderFit: placeholderFit,
      alignment: alignment,
      repeat: repeat,
      matchTextDirection: matchTextDirection,
      excludeFromSemantics: excludeFromSemantics,
      imageSemanticLabel: resolvedSemanticLabel,
      placeholderColor: placeholderColor,
      placeholderColorBlendMode: placeholderColorBlendMode,
      placeholderErrorBuilder: placeholderErrorBuilder,
      imageErrorBuilder: imageErrorBuilder,
    );
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

  const TomImageIcon({
    super.key,
    super.tomId,
    super.tomGroup,
    this.image,
    this.size,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedSemanticLabel = semanticLabel ??
        (tomId != null ? resolveResource(context, 'semanticLabel') : null);

    return ImageIcon(
      image,
      size: size,
      color: color,
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

  const TomInkImage({
    super.key,
    super.tomId,
    super.tomGroup,
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
    return Ink.image(
      padding: padding,
      image: image,
      colorFilter: colorFilter,
      fit: fit,
      alignment: alignment,
      centerSlice: centerSlice,
      repeat: repeat,
      width: width,
      height: height,
      child: child,
    );
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

  const TomNetworkImage({
    super.key,
    super.tomId,
    super.tomGroup,
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
        (tomId != null ? resolveResource(context, 'semanticLabel') : null);

    return Image.network(
      src,
      scale: scale,
      headers: headers,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      filterQuality: filterQuality,
      isAntiAlias: isAntiAlias,
      color: color,
      colorBlendMode: colorBlendMode,
      semanticLabel: resolvedSemanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      frameBuilder: frameBuilder,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
    );
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

  const TomAssetImage({
    super.key,
    super.tomId,
    super.tomGroup,
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
        (tomId != null ? resolveResource(context, 'semanticLabel') : null);

    return Image.asset(
      name,
      bundle: bundle,
      package: package,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      filterQuality: filterQuality,
      isAntiAlias: isAntiAlias,
      color: color,
      colorBlendMode: colorBlendMode,
      semanticLabel: resolvedSemanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
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

  const TomFileImage({
    super.key,
    super.tomId,
    super.tomGroup,
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
        (tomId != null ? resolveResource(context, 'semanticLabel') : null);

    return Image(
      image: FileImage(File(filePath), scale: scale),
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      filterQuality: filterQuality,
      isAntiAlias: isAntiAlias,
      color: color,
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

  const TomAnimatedIcon({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.icon,
    required this.progress,
    this.color,
    this.size,
    this.semanticLabel,
    this.textDirection,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedSemanticLabel = semanticLabel ??
        (tomId != null ? resolveResource(context, 'semanticLabel') : null);
    return AnimatedIcon(
      icon: icon,
      progress: progress,
      color: color,
      size: size,
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
  final bool enabled;
  final Widget? child;

  const TomImageFiltered({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.imageFilter,
    this.enabled = true,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return ImageFiltered(
      imageFilter: imageFilter,
      enabled: enabled,
      child: child,
    );
  }
}
