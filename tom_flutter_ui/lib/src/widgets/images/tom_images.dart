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
