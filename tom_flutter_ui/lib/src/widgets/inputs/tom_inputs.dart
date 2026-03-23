import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../widget_base/tom_family_base.dart';

/// Tom wrapper for [TextField].
///
/// Adds ID, group, authorization, resource resolution for label/hint.
class TomTextField extends TomInputBase {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final bool autofocus;
  final bool obscureText;
  final bool autocorrect;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool readOnly;
  final String? label;
  final String? hint;

  const TomTextField({
    super.key,
    super.tomId,
    super.tomGroup,
    this.controller,
    this.focusNode,
    this.decoration,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.autofocus = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.label,
    this.hint,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = label ?? (tomId != null ? resolveResource(context, 'label') : null);
    final resolvedHint = hint ?? (tomId != null ? resolveResource(context, 'hint') : null);

    final effectiveDecoration =
        (decoration ?? const InputDecoration()).copyWith(
      labelText: resolvedLabel,
      hintText: resolvedHint,
    );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: effectiveDecoration,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: style,
      textAlign: textAlign,
      textDirection: textDirection,
      autofocus: autofocus,
      obscureText: obscureText,
      autocorrect: autocorrect,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onSubmitted: onSubmitted,
      enabled: enabled,
      readOnly: readOnly,
    );
  }
}

/// Tom wrapper for [TextFormField].
///
/// Like [TomTextField] but integrates with Flutter's [Form] system
/// for validation. Adds Tom ID, group, authorization, resource resolution.
class TomTextFormField extends TomInputBase {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final bool autofocus;
  final bool obscureText;
  final bool autocorrect;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldSetter<String>? onSaved;
  final FormFieldValidator<String>? validator;
  final String? initialValue;
  final bool enabled;
  final bool readOnly;
  final AutovalidateMode? autovalidateMode;
  final String? label;
  final String? hint;

  const TomTextFormField({
    super.key,
    super.tomId,
    super.tomGroup,
    this.controller,
    this.focusNode,
    this.decoration,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.autofocus = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onEditingComplete,
    this.onFieldSubmitted,
    this.onSaved,
    this.validator,
    this.initialValue,
    this.enabled = true,
    this.readOnly = false,
    this.autovalidateMode,
    this.label,
    this.hint,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel =
        label ?? (tomId != null ? resolveResource(context, 'label') : null);
    final resolvedHint =
        hint ?? (tomId != null ? resolveResource(context, 'hint') : null);

    final effectiveDecoration =
        (decoration ?? const InputDecoration()).copyWith(
      labelText: resolvedLabel,
      hintText: resolvedHint,
    );

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: effectiveDecoration,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: style,
      textAlign: textAlign,
      textDirection: textDirection,
      autofocus: autofocus,
      obscureText: obscureText,
      autocorrect: autocorrect,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onFieldSubmitted: onFieldSubmitted,
      onSaved: onSaved,
      validator: validator,
      initialValue: initialValue,
      enabled: enabled,
      readOnly: readOnly,
      autovalidateMode: autovalidateMode,
    );
  }
}

/// Tom wrapper for [SearchBar].
///
/// Adds ID, group, authorization, and resource resolution for hint text.
class TomSearchBar extends TomInputBase {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final Widget? leading;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final WidgetStateProperty<double?>? elevation;
  final WidgetStateProperty<Color?>? backgroundColor;
  final WidgetStateProperty<Color?>? surfaceTintColor;
  final WidgetStateProperty<Color?>? overlayColor;
  final WidgetStateProperty<BorderSide?>? side;
  final WidgetStateProperty<OutlinedBorder?>? shape;
  final WidgetStateProperty<EdgeInsetsGeometry?>? padding;
  final WidgetStateProperty<TextStyle?>? textStyle;
  final WidgetStateProperty<TextStyle?>? hintStyle;
  final BoxConstraints? constraints;
  final bool autoFocus;
  final TextCapitalization textCapitalization;

  const TomSearchBar({
    super.key,
    super.tomId,
    super.tomGroup,
    this.controller,
    this.focusNode,
    this.hintText,
    this.leading,
    this.trailing,
    this.onChanged,
    this.onTap,
    this.elevation,
    this.backgroundColor,
    this.surfaceTintColor,
    this.overlayColor,
    this.side,
    this.shape,
    this.padding,
    this.textStyle,
    this.hintStyle,
    this.constraints,
    this.autoFocus = false,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedHint =
        hintText ?? (tomId != null ? resolveResource(context, 'hint') : null);

    return SearchBar(
      controller: controller,
      focusNode: focusNode,
      hintText: resolvedHint,
      leading: leading,
      onChanged: onChanged,
      onTap: onTap,
      elevation: elevation,
      backgroundColor: backgroundColor,
      surfaceTintColor: surfaceTintColor,
      overlayColor: overlayColor,
      side: side,
      shape: shape,
      padding: padding,
      textStyle: textStyle,
      hintStyle: hintStyle,
      constraints: constraints,
      autoFocus: autoFocus,
      textCapitalization: textCapitalization,
    );
  }
}

/// Tom wrapper for [Autocomplete].
///
/// Adds ID, group, authorization.
class TomAutocomplete<T extends Object> extends TomInputBase {
  final AutocompleteOptionsBuilder<T> optionsBuilder;
  final AutocompleteOptionToString<T> displayStringForOption;
  final AutocompleteFieldViewBuilder fieldViewBuilder;
  final AutocompleteOnSelected<T>? onSelected;
  final AutocompleteOptionsViewBuilder<T>? optionsViewBuilder;
  final OptionsViewOpenDirection optionsViewOpenDirection;
  final TextEditingValue? initialValue;

  const TomAutocomplete({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.optionsBuilder,
    this.displayStringForOption = RawAutocomplete.defaultStringForOption,
    this.fieldViewBuilder = _defaultFieldViewBuilder,
    this.onSelected,
    this.optionsViewBuilder,
    this.optionsViewOpenDirection = OptionsViewOpenDirection.down,
    this.initialValue,
  });

  static Widget _defaultFieldViewBuilder(
    BuildContext context,
    TextEditingController textEditingController,
    FocusNode focusNode,
    VoidCallback onFieldSubmitted,
  ) {
    return TextFormField(
      controller: textEditingController,
      focusNode: focusNode,
      onFieldSubmitted: (value) => onFieldSubmitted(),
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    return Autocomplete<T>(
      optionsBuilder: optionsBuilder,
      displayStringForOption: displayStringForOption,
      fieldViewBuilder: fieldViewBuilder,
      onSelected: onSelected,
      optionsViewBuilder: optionsViewBuilder,
      optionsViewOpenDirection: optionsViewOpenDirection,
      initialValue: initialValue,
    );
  }
}

/// Tom wrapper for [SearchAnchor].
///
/// Adds ID, group, authorization, and resource resolution.
class TomSearchAnchor extends TomInputBase {
  final bool isFullScreen;
  final SearchController? searchController;
  final SearchAnchorChildBuilder? builder;
  final SuggestionsBuilder suggestionsBuilder;
  final Widget? viewLeading;
  final List<Widget>? viewTrailing;
  final String? viewHintText;
  final Color? viewBackgroundColor;
  final double? viewElevation;
  final Color? viewSurfaceTintColor;
  final BorderSide? viewSide;
  final OutlinedBorder? viewShape;
  final TextStyle? headerTextStyle;
  final TextStyle? headerHintStyle;
  final Color? dividerColor;
  final BoxConstraints? viewConstraints;
  final TextCapitalization? textCapitalization;
  final TextInputAction? viewOnSubmitted;

  const TomSearchAnchor({
    super.key,
    super.tomId,
    super.tomGroup,
    this.isFullScreen = false,
    this.searchController,
    this.builder,
    required this.suggestionsBuilder,
    this.viewLeading,
    this.viewTrailing,
    this.viewHintText,
    this.viewBackgroundColor,
    this.viewElevation,
    this.viewSurfaceTintColor,
    this.viewSide,
    this.viewShape,
    this.headerTextStyle,
    this.headerHintStyle,
    this.dividerColor,
    this.viewConstraints,
    this.textCapitalization,
    this.viewOnSubmitted,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedHint =
        viewHintText ?? (tomId != null ? resolveResource(context, 'hint') : null);

    return SearchAnchor(
      isFullScreen: isFullScreen,
      searchController: searchController,
      builder: builder ??
          (BuildContext context, SearchController controller) {
            return SearchBar(
              controller: controller,
              hintText: resolvedHint,
              onTap: () => controller.openView(),
              onChanged: (_) => controller.openView(),
            );
          },
      suggestionsBuilder: suggestionsBuilder,
      viewLeading: viewLeading,
      viewTrailing: viewTrailing,
      viewHintText: resolvedHint,
      viewBackgroundColor: viewBackgroundColor,
      viewElevation: viewElevation,
      viewSurfaceTintColor: viewSurfaceTintColor,
      viewSide: viewSide,
      viewShape: viewShape,
      headerTextStyle: headerTextStyle,
      headerHintStyle: headerHintStyle,
      dividerColor: dividerColor,
      viewConstraints: viewConstraints,
      textCapitalization: textCapitalization,
    );
  }
}

/// Tom wrapper for [EditableText].
///
/// Low-level text editing widget. Adds ID, group, authorization,
/// and resource resolution.
class TomEditableText extends TomInputBase {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool readOnly;
  final String obscuringCharacter;
  final bool obscureText;
  final bool autocorrect;
  final TextStyle style;
  final StrutStyle? strutStyle;
  final Color cursorColor;
  final Color? backgroundCursorColor;
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final bool autofocus;
  final Color? selectionColor;
  final TextSelectionControls? selectionControls;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final TextScaler? textScaler;
  final bool showCursor;
  final bool showSelectionHandles;
  final double cursorWidth;
  final double? cursorHeight;
  final Radius? cursorRadius;
  final Offset? cursorOffset;
  final ScrollPhysics? scrollPhysics;
  final ScrollController? scrollController;
  final SelectionChangedCallback? onSelectionChanged;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final bool rendererIgnoresPointer;
  final bool enableInteractiveSelection;
  final Clip clipBehavior;

  const TomEditableText({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.controller,
    required this.focusNode,
    this.readOnly = false,
    this.obscuringCharacter = '•',
    this.obscureText = false,
    this.autocorrect = true,
    required this.style,
    this.strutStyle,
    required this.cursorColor,
    this.backgroundCursorColor,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.autofocus = false,
    this.selectionColor,
    this.selectionControls,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.textScaler,
    this.showCursor = true,
    this.showSelectionHandles = false,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorOffset,
    this.scrollPhysics,
    this.scrollController,
    this.onSelectionChanged,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.rendererIgnoresPointer = false,
    this.enableInteractiveSelection = true,
    this.clipBehavior = Clip.hardEdge,
  });

  @override
  Widget buildContent(BuildContext context) {
    return EditableText(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      obscuringCharacter: obscuringCharacter,
      obscureText: obscureText,
      autocorrect: autocorrect,
      style: style,
      strutStyle: strutStyle,
      cursorColor: cursorColor,
      backgroundCursorColor: backgroundCursorColor ?? Colors.grey,
      maxLines: maxLines,
      minLines: minLines,
      expands: expands,
      autofocus: autofocus,
      selectionColor: selectionColor,
      selectionControls: selectionControls,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      textAlign: textAlign,
      textDirection: textDirection,
      textScaler: textScaler,
      showCursor: showCursor,
      showSelectionHandles: showSelectionHandles,
      cursorWidth: cursorWidth,
      cursorHeight: cursorHeight,
      cursorRadius: cursorRadius,
      cursorOffset: cursorOffset,
      scrollPhysics: scrollPhysics,
      scrollController: scrollController,
      onSelectionChanged: onSelectionChanged,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onSubmitted: onSubmitted,
      rendererIgnoresPointer: rendererIgnoresPointer,
      enableInteractiveSelection: enableInteractiveSelection,
      clipBehavior: clipBehavior,
    );
  }
}

/// Tom wrapper for [CupertinoTextField].
///
/// iOS-style text field. Adds ID, group, authorization,
/// and resource resolution for placeholder/prefix.
class TomCupertinoTextField extends TomInputBase {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final BoxDecoration? decoration;
  final EdgeInsetsGeometry padding;
  final String? placeholder;
  final TextStyle? placeholderStyle;
  final Widget? prefix;
  final OverlayVisibilityMode prefixMode;
  final Widget? suffix;
  final OverlayVisibilityMode suffixMode;
  final OverlayVisibilityMode clearButtonMode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final bool autofocus;
  final bool obscureText;
  final bool autocorrect;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool readOnly;

  const TomCupertinoTextField({
    super.key,
    super.tomId,
    super.tomGroup,
    this.controller,
    this.focusNode,
    this.decoration,
    this.padding = const EdgeInsets.all(7.0),
    this.placeholder,
    this.placeholderStyle,
    this.prefix,
    this.prefixMode = OverlayVisibilityMode.always,
    this.suffix,
    this.suffixMode = OverlayVisibilityMode.editing,
    this.clearButtonMode = OverlayVisibilityMode.never,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.autofocus = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedPlaceholder =
        placeholder ?? (tomId != null ? resolveResource(context, 'hint') : null);

    return CupertinoTextField(
      controller: controller,
      focusNode: focusNode,
      decoration: decoration,
      padding: padding,
      placeholder: resolvedPlaceholder,
      placeholderStyle: placeholderStyle,
      prefix: prefix,
      prefixMode: prefixMode,
      suffix: suffix,
      suffixMode: suffixMode,
      clearButtonMode: clearButtonMode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: style,
      textAlign: textAlign,
      textDirection: textDirection,
      autofocus: autofocus,
      obscureText: obscureText,
      autocorrect: autocorrect,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onSubmitted: onSubmitted,
      enabled: enabled,
      readOnly: readOnly,
    );
  }
}
