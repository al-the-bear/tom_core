import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../widget_base/tom_family_base.dart';

/// Tom wrapper for [Text].
///
/// Resolves the text string from resources when [text] is not provided.
class TomText extends TomLabelBase {
  final String? text;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;

  const TomText({
    super.key,
    super.tomId,
    super.tomGroup,
    super.tomStyleVariant,
    this.text,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedText = text ?? resolveResource(context, 'label');

    return Text(
      resolvedText,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
    );
  }
}

/// Tom wrapper for [SelectableText].
///
/// Resolves the text string from resources when [text] is not provided.
class TomSelectableText extends TomLabelBase {
  final String? text;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool showCursor;
  final int? minLines;
  final double cursorWidth;
  final double? cursorHeight;
  final Radius? cursorRadius;
  final Color? cursorColor;
  final DragStartBehavior? dragStartBehavior;
  final VoidCallback? onTap;
  final ScrollPhysics? scrollPhysics;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;

  const TomSelectableText({
    super.key,
    super.tomId,
    super.tomGroup,
    super.tomStyleVariant,
    this.text,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.maxLines,
    this.focusNode,
    this.autofocus = false,
    this.showCursor = false,
    this.minLines,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorColor,
    this.dragStartBehavior,
    this.onTap,
    this.scrollPhysics,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedText = text ?? resolveResource(context, 'label');

    return SelectableText(
      resolvedText,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      maxLines: maxLines,
      focusNode: focusNode,
      autofocus: autofocus,
      showCursor: showCursor,
      minLines: minLines,
      cursorWidth: cursorWidth,
      cursorHeight: cursorHeight,
      cursorRadius: cursorRadius,
      cursorColor: cursorColor,
      onTap: onTap,
      scrollPhysics: scrollPhysics,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
    );
  }
}
