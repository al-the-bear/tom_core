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
    super.tomStyleVariant,
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
    super.tomStyleVariant,
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
