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
