import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_style_resolvers.dart';

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
  final StrutStyle? strutStyle;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final TextDirection? textDirection;
  final bool autofocus;
  final bool obscureText;
  final bool autocorrect;
  final SmartDashesType? smartDashesType;
  final SmartQuotesType? smartQuotesType;
  final bool enableSuggestions;
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final int? maxLength;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final AppPrivateCommandCallback? onAppPrivateCommand;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final bool? ignorePointers;
  final bool readOnly;
  final bool? showCursor;
  final String? obscuringCharacter;
  final double? cursorWidth;
  final double? cursorHeight;
  final Radius? cursorRadius;
  final Color? cursorColor;
  final Color? cursorErrorColor;
  final BoxHeightStyle selectionHeightStyle;
  final BoxWidthStyle selectionWidthStyle;
  final Brightness? keyboardAppearance;
  final EdgeInsets scrollPadding;
  final DragStartBehavior dragStartBehavior;
  final bool? enableInteractiveSelection;
  final TextSelectionControls? selectionControls;
  final GestureTapCallback? onTap;
  final bool onTapAlwaysCalled;
  final TapRegionCallback? onTapOutside;
  final MouseCursor? mouseCursor;
  final ScrollController? scrollController;
  final ScrollPhysics? scrollPhysics;
  final Iterable<String>? autofillHints;
  final Clip clipBehavior;
  final String? restorationId;
  final bool scribbleEnabled;
  final bool enableIMEPersonalizedLearning;
  final ContentInsertionConfiguration? contentInsertionConfiguration;
  final EditableTextContextMenuBuilder? contextMenuBuilder;
  final bool canRequestFocus;
  final SpellCheckConfiguration? spellCheckConfiguration;
  final TextMagnifierConfiguration? magnifierConfiguration;
  final UndoHistoryController? undoController;
  final String? label;
  final String? hint;
  final InputCounterWidgetBuilder? buildCounter;

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
    this.strutStyle,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.textDirection,
    this.autofocus = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.smartDashesType,
    this.smartQuotesType,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.maxLength,
    this.maxLengthEnforcement,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.onAppPrivateCommand,
    this.inputFormatters,
    this.enabled = true,
    this.ignorePointers,
    this.readOnly = false,
    this.showCursor,
    this.obscuringCharacter,
    this.cursorWidth,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorColor,
    this.cursorErrorColor,
    this.selectionHeightStyle = BoxHeightStyle.tight,
    this.selectionWidthStyle = BoxWidthStyle.tight,
    this.keyboardAppearance,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.dragStartBehavior = DragStartBehavior.start,
    this.enableInteractiveSelection,
    this.selectionControls,
    this.onTap,
    this.onTapAlwaysCalled = false,
    this.onTapOutside,
    this.mouseCursor,
    this.scrollController,
    this.scrollPhysics,
    this.autofillHints,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.scribbleEnabled = true,
    this.enableIMEPersonalizedLearning = true,
    this.contentInsertionConfiguration,
    this.contextMenuBuilder,
    this.canRequestFocus = true,
    this.spellCheckConfiguration,
    this.magnifierConfiguration,
    this.undoController,
    this.label,
    this.hint,
    this.buildCounter,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = label ?? resolveResourceOrFail('label');
    final resolvedHint = hint ?? (tomId != null ? resolveResourceOrFail('hint') : null);

    // Phase 2: Resolve optional parameters from resources
    final resolvedCursorColor =
        cursorColor ?? resolveColorOrNull('cursorColor');
    final resolvedCursorErrorColor =
        cursorErrorColor ?? resolveColorOrNull('cursorErrorColor');
    final resolvedCursorHeight =
        cursorHeight ?? resolveDoubleOrNull('cursorHeight');
    final resolvedCursorWidth =
        cursorWidth ?? resolveDoubleOrNull('cursorWidth') ?? 2.0;
    final resolvedMaxLines =
        maxLines ?? resolveIntOrNull('maxLines');
    final resolvedMinLines =
        minLines ?? resolveIntOrNull('minLines');
    final resolvedMaxLength =
        maxLength ?? resolveIntOrNull('maxLength');
    final resolvedAutofocus =
        resolveBoolOrNull('autofocus') ?? autofocus;
    final resolvedObscureText =
        resolveBoolOrNull('obscureText') ?? obscureText;
    final resolvedAutocorrect =
        resolveBoolOrNull('autocorrect') ?? autocorrect;
    final resolvedEnableSuggestions =
        resolveBoolOrNull('enableSuggestions') ?? enableSuggestions;
    final resolvedExpands =
        resolveBoolOrNull('expands') ?? expands;
    final resolvedEnabled =
        resolveBoolOrNull('enabled') ?? enabled;
    final resolvedReadOnly =
        resolveBoolOrNull('readOnly') ?? readOnly;
    final resolvedShowCursor =
        showCursor ?? resolveBoolOrNull('showCursor');
    final resolvedObscuringCharacter =
        obscuringCharacter ?? resolveResourceOrNull('obscuringCharacter') ?? '•';
    final resolvedScrollPadding =
        resolveEdgeInsetsOrNull('scrollPadding') ?? scrollPadding;
    final resolvedEnableInteractiveSelection =
        enableInteractiveSelection ?? resolveBoolOrNull('enableInteractiveSelection');
    final resolvedRestorationId =
        restorationId ?? resolveResourceOrNull('restorationId');
    final resolvedScribbleEnabled =
        resolveBoolOrNull('scribbleEnabled') ?? scribbleEnabled;
    final resolvedEnableIMEPersonalizedLearning =
        resolveBoolOrNull('enableIMEPersonalizedLearning') ?? enableIMEPersonalizedLearning;
    final resolvedCanRequestFocus =
        resolveBoolOrNull('canRequestFocus') ?? canRequestFocus;

    // Phase 3: Resolve TextStyle from resources
    final resolvedStyle = style ?? _resolveTextStyle(context);

    // Phase 3: Resolve InputDecoration from resources and merge with explicit settings
    final resolvedDecoration = _resolveDecoration(resolvedLabel, resolvedHint);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: resolvedDecoration,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: resolvedStyle,
      strutStyle: strutStyle ?? _resolveStrutStyle('strutStyle'),
      textAlign: textAlign,
      textAlignVertical: textAlignVertical,
      textDirection: textDirection,
      autofocus: resolvedAutofocus,
      obscureText: resolvedObscureText,
      obscuringCharacter: resolvedObscuringCharacter,
      autocorrect: resolvedAutocorrect,
      smartDashesType: smartDashesType,
      smartQuotesType: smartQuotesType,
      enableSuggestions: resolvedEnableSuggestions,
      maxLines: resolvedMaxLines,
      minLines: resolvedMinLines,
      expands: resolvedExpands,
      maxLength: resolvedMaxLength,
      maxLengthEnforcement: maxLengthEnforcement,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onSubmitted: onSubmitted,
      onAppPrivateCommand: onAppPrivateCommand,
      inputFormatters: inputFormatters,
      enabled: resolvedEnabled,
      ignorePointers: ignorePointers,
      readOnly: resolvedReadOnly,
      showCursor: resolvedShowCursor,
      cursorWidth: resolvedCursorWidth,
      cursorHeight: resolvedCursorHeight,
      cursorRadius: cursorRadius,
      cursorColor: resolvedCursorColor,
      cursorErrorColor: resolvedCursorErrorColor,
      selectionHeightStyle: selectionHeightStyle,
      selectionWidthStyle: selectionWidthStyle,
      keyboardAppearance: keyboardAppearance,
      scrollPadding: resolvedScrollPadding,
      dragStartBehavior: dragStartBehavior,
      enableInteractiveSelection: resolvedEnableInteractiveSelection,
      selectionControls: selectionControls,
      onTap: onTap,
      onTapAlwaysCalled: onTapAlwaysCalled,
      onTapOutside: onTapOutside,
      mouseCursor: mouseCursor,
      scrollController: scrollController,
      scrollPhysics: scrollPhysics ?? _resolveScrollPhysics('scrollPhysics'),
      autofillHints: autofillHints,
      clipBehavior: clipBehavior,
      restorationId: resolvedRestorationId,
      scribbleEnabled: resolvedScribbleEnabled,
      enableIMEPersonalizedLearning: resolvedEnableIMEPersonalizedLearning,
      contentInsertionConfiguration: contentInsertionConfiguration,
      contextMenuBuilder: contextMenuBuilder,
      canRequestFocus: resolvedCanRequestFocus,
      spellCheckConfiguration: spellCheckConfiguration,
      magnifierConfiguration: magnifierConfiguration,
      undoController: undoController,
      buildCounter: buildCounter,
    );
  }

  /// Phase 3: Resolves TextStyle from resources.
  TextStyle? _resolveTextStyle(BuildContext context) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, 'style');
  }

  /// Phase 3: Resolves InputDecoration from resources and merges with explicit values.
  InputDecoration _resolveDecoration(String resolvedLabel, String? resolvedHint) {
    final basePath = resolveResourceBasePath();

    // Start with explicit decoration or empty
    InputDecoration base = decoration ?? const InputDecoration();

    // Try to resolve InputDecoration from resources
    if (basePath != null) {
      final resourceDecoration =
          TomStyleResolvers.resolveInputDecoration(basePath, 'decoration');
      if (resourceDecoration != null) {
        // Merge: explicit decoration properties take precedence
        base = resourceDecoration.copyWith(
          labelText: base.labelText,
          hintText: base.hintText,
          helperText: base.helperText,
          errorText: base.errorText,
          prefixIcon: base.prefixIcon,
          suffixIcon: base.suffixIcon,
          // Keep other explicit properties if set
        );
      }
    }

    // Apply resolved label and hint
    return base.copyWith(
      labelText: resolvedLabel,
      hintText: resolvedHint,
    );
  }

  StrutStyle? _resolveStrutStyle(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveStrutStyle(basePath, suffix);
  }

  ScrollPhysics? _resolveScrollPhysics(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveScrollPhysics(basePath, suffix);
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
    final resolvedLabel = label ?? resolveResourceOrFail('label');
    final resolvedHint =
        hint ?? (tomId != null ? resolveResourceOrFail('hint') : null);

    // Phase 2: Resolve optional parameters from resources
    final resolvedMaxLines =
        maxLines ?? resolveIntOrNull('maxLines');
    final resolvedMinLines =
        minLines ?? resolveIntOrNull('minLines');
    final resolvedMaxLength =
        maxLength ?? resolveIntOrNull('maxLength');
    final resolvedAutofocus =
        resolveBoolOrNull('autofocus') ?? autofocus;
    final resolvedObscureText =
        resolveBoolOrNull('obscureText') ?? obscureText;
    final resolvedAutocorrect =
        resolveBoolOrNull('autocorrect') ?? autocorrect;
    final resolvedInitialValue =
        initialValue ?? resolveResourceOrNull('initialValue');
    final resolvedEnabled =
        resolveBoolOrNull('enabled') ?? enabled;
    final resolvedReadOnly =
        resolveBoolOrNull('readOnly') ?? readOnly;

    // Phase 3: Resolve TextStyle from resources
    final resolvedStyle = style ?? _resolveTextStyle(context);

    // Phase 3: Resolve InputDecoration from resources and merge with explicit settings
    final resolvedDecoration = _resolveDecoration(resolvedLabel, resolvedHint);

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: resolvedDecoration,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: resolvedStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      autofocus: resolvedAutofocus,
      obscureText: resolvedObscureText,
      autocorrect: resolvedAutocorrect,
      maxLines: resolvedMaxLines,
      minLines: resolvedMinLines,
      maxLength: resolvedMaxLength,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onFieldSubmitted: onFieldSubmitted,
      onSaved: onSaved,
      validator: validator,
      initialValue: resolvedInitialValue,
      enabled: resolvedEnabled,
      readOnly: resolvedReadOnly,
      autovalidateMode: autovalidateMode,
    );
  }

  /// Phase 3: Resolves TextStyle from resources.
  TextStyle? _resolveTextStyle(BuildContext context) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, 'style');
  }

  /// Phase 3: Resolves InputDecoration from resources and merges with explicit values.
  InputDecoration _resolveDecoration(String resolvedLabel, String? resolvedHint) {
    final basePath = resolveResourceBasePath();

    // Start with explicit decoration or empty
    InputDecoration base = decoration ?? const InputDecoration();

    // Try to resolve InputDecoration from resources
    if (basePath != null) {
      final resourceDecoration =
          TomStyleResolvers.resolveInputDecoration(basePath, 'decoration');
      if (resourceDecoration != null) {
        // Merge: explicit decoration properties take precedence
        base = resourceDecoration.copyWith(
          labelText: base.labelText,
          hintText: base.hintText,
          helperText: base.helperText,
          errorText: base.errorText,
          prefixIcon: base.prefixIcon,
          suffixIcon: base.suffixIcon,
        );
      }
    }

    // Apply resolved label and hint
    return base.copyWith(
      labelText: resolvedLabel,
      hintText: resolvedHint,
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
  final Iterable<Widget>? trailing;
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
        hintText ?? (tomId != null ? resolveResourceOrFail('hint') : null);

    // Phase 2: Resolve optional parameters from resources
    final resolvedAutoFocus =
        resolveBoolOrNull('autoFocus') ?? autoFocus;

    return SearchBar(
      controller: controller,
      focusNode: focusNode,
      hintText: resolvedHint,
      leading: leading,
      trailing: trailing,
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
      constraints: constraints ?? _resolveBoxConstraints('constraints'),
      autoFocus: resolvedAutoFocus,
      textCapitalization: textCapitalization,
    );
  }

  BoxConstraints? _resolveBoxConstraints(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBoxConstraints(basePath, suffix);
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
        viewHintText ?? (tomId != null ? resolveResourceOrFail('hint') : null);

    // Phase 2: Resolve optional parameters from resources
    final resolvedViewBackgroundColor =
        viewBackgroundColor ?? resolveColorOrNull('viewBackgroundColor');
    final resolvedViewElevation =
        viewElevation ?? resolveDoubleOrNull('viewElevation');
    final resolvedViewSurfaceTintColor =
        viewSurfaceTintColor ?? resolveColorOrNull('viewSurfaceTintColor');
    final resolvedDividerColor =
        dividerColor ?? resolveColorOrNull('dividerColor');

    // Phase 3: Resolve TextStyle from resources
    final resolvedHeaderTextStyle = headerTextStyle ?? _resolveTextStyle('headerTextStyle');
    final resolvedHeaderHintStyle = headerHintStyle ?? _resolveTextStyle('headerHintStyle');

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
      viewBackgroundColor: resolvedViewBackgroundColor,
      viewElevation: resolvedViewElevation,
      viewSurfaceTintColor: resolvedViewSurfaceTintColor,
      viewSide: viewSide,
      viewShape: viewShape,
      headerTextStyle: resolvedHeaderTextStyle,
      headerHintStyle: resolvedHeaderHintStyle,
      dividerColor: resolvedDividerColor,
      viewConstraints: viewConstraints,
      textCapitalization: textCapitalization,
    );
  }

  /// Phase 3: Resolves TextStyle from resources.
  TextStyle? _resolveTextStyle(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
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
  final double? cursorWidth;
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
    this.cursorWidth,
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
    // Phase 2: Resolve optional parameters from resources
    final resolvedBackgroundCursorColor =
        backgroundCursorColor ?? resolveColorOrNull('backgroundCursorColor') ?? Colors.grey;
    final resolvedSelectionColor =
        selectionColor ?? resolveColorOrNull('selectionColor');
    final resolvedCursorHeight =
        cursorHeight ?? resolveDoubleOrNull('cursorHeight');
    final resolvedCursorWidth =
        cursorWidth ?? resolveDoubleOrNull('cursorWidth') ?? 2.0;
    final resolvedMaxLines =
        maxLines ?? resolveIntOrNull('maxLines');
    final resolvedMinLines =
        minLines ?? resolveIntOrNull('minLines');

    // Phase 3: Style is required, so no resource resolution for this widget
    // (EditableText requires an explicit style)

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
      backgroundCursorColor: resolvedBackgroundCursorColor,
      maxLines: resolvedMaxLines,
      minLines: resolvedMinLines,
      expands: expands,
      autofocus: autofocus,
      selectionColor: resolvedSelectionColor,
      selectionControls: selectionControls,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      textAlign: textAlign,
      textDirection: textDirection,
      textScaler: textScaler,
      showCursor: showCursor,
      showSelectionHandles: showSelectionHandles,
      cursorWidth: resolvedCursorWidth,
      cursorHeight: resolvedCursorHeight,
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
  final EdgeInsetsGeometry? padding;
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
    this.padding,
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
        placeholder ?? (tomId != null ? resolveResourceOrFail('hint') : null);

    // Phase 2: Resolve optional parameters from resources
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding') ?? const EdgeInsets.all(7.0);
    final resolvedMaxLines =
        maxLines ?? resolveIntOrNull('maxLines');
    final resolvedMinLines =
        minLines ?? resolveIntOrNull('minLines');
    final resolvedMaxLength =
        maxLength ?? resolveIntOrNull('maxLength');

    // Phase 3: Resolve TextStyle from resources
    final resolvedStyle = style ?? _resolveTextStyle('style');
    final resolvedPlaceholderStyle = placeholderStyle ?? _resolveTextStyle('placeholderStyle');

    return CupertinoTextField(
      controller: controller,
      focusNode: focusNode,
      decoration: decoration,
      padding: resolvedPadding,
      placeholder: resolvedPlaceholder,
      placeholderStyle: resolvedPlaceholderStyle,
      prefix: prefix,
      prefixMode: prefixMode,
      suffix: suffix,
      suffixMode: suffixMode,
      clearButtonMode: clearButtonMode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: resolvedStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      autofocus: autofocus,
      obscureText: obscureText,
      autocorrect: autocorrect,
      maxLines: resolvedMaxLines,
      minLines: resolvedMinLines,
      maxLength: resolvedMaxLength,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onSubmitted: onSubmitted,
      enabled: enabled,
      readOnly: readOnly,
    );
  }

  /// Phase 3: Resolves TextStyle from resources.
  TextStyle? _resolveTextStyle(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
  }
}

// ============================================================================
// Section II Inputs — Date/Time pickers, Form, Cupertino form fields
// ============================================================================

/// Tom wrapper for [CalendarDatePicker].
///
/// Inline calendar date selector. Auth makes it readonly or hidden.
class TomCalendarDatePicker extends TomInputBase {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateChanged;
  final DateTime? currentDate;
  final SelectableDayPredicate? selectableDayPredicate;

  const TomCalendarDatePicker({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateChanged,
    this.currentDate,
    this.selectableDayPredicate,
  });

  @override
  Widget buildContent(BuildContext context) {
    return CalendarDatePicker(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      onDateChanged: onDateChanged,
      currentDate: currentDate,
      selectableDayPredicate: selectableDayPredicate,
    );
  }
}

/// Tom wrapper for [CupertinoDatePicker].
///
/// Cupertino date wheel picker. Auth for readonly/hidden.
class TomCupertinoDatePicker extends TomInputBase {
  final CupertinoDatePickerMode mode;
  final ValueChanged<DateTime> onDateTimeChanged;
  final DateTime? initialDateTime;
  final DateTime? minimumDate;
  final DateTime? maximumDate;
  final int minimumYear;
  final int? maximumYear;
  final int minuteInterval;
  final bool use24hFormat;
  final Color? backgroundColor;
  final bool showDayOfWeek;
  final double? itemExtent;

  const TomCupertinoDatePicker({
    super.key,
    super.tomId,
    super.tomGroup,
    this.mode = CupertinoDatePickerMode.dateAndTime,
    required this.onDateTimeChanged,
    this.initialDateTime,
    this.minimumDate,
    this.maximumDate,
    this.minimumYear = 1,
    this.maximumYear,
    this.minuteInterval = 1,
    this.use24hFormat = false,
    this.backgroundColor,
    this.showDayOfWeek = false,
    this.itemExtent,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedItemExtent =
        itemExtent ?? resolveDoubleOrNull('itemExtent') ?? 32.0;

    return CupertinoDatePicker(
      mode: mode,
      onDateTimeChanged: onDateTimeChanged,
      initialDateTime: initialDateTime,
      minimumDate: minimumDate,
      maximumDate: maximumDate,
      minimumYear: minimumYear,
      maximumYear: maximumYear,
      minuteInterval: minuteInterval,
      use24hFormat: use24hFormat,
      backgroundColor: resolvedBackgroundColor,
      showDayOfWeek: showDayOfWeek,
      itemExtent: resolvedItemExtent,
    );
  }
}

/// Tom wrapper for [CupertinoSearchTextField].
///
/// Cupertino search input. Auth can restrict search; resource for placeholder.
class TomCupertinoSearchTextField extends TomInputBase {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onSuffixTap;
  final TextStyle? style;
  final String? placeholder;
  final TextStyle? placeholderStyle;
  final BoxDecoration? decoration;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? itemColor;
  final double? itemSize;
  final Widget prefixIcon;
  final Icon suffixIcon;
  final OverlayVisibilityMode suffixMode;
  final String? restorationId;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool autocorrect;
  final bool enabled;
  final SmartQuotesType? smartQuotesType;
  final SmartDashesType? smartDashesType;

  const TomCupertinoSearchTextField({
    super.key,
    super.tomId,
    super.tomGroup,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onSuffixTap,
    this.style,
    this.placeholder,
    this.placeholderStyle,
    this.decoration,
    this.backgroundColor,
    this.borderRadius,
    this.padding,
    this.itemColor,
    this.itemSize,
    this.prefixIcon = const Icon(CupertinoIcons.search),
    this.suffixIcon = const Icon(CupertinoIcons.xmark_circle_fill),
    this.suffixMode = OverlayVisibilityMode.editing,
    this.restorationId,
    this.focusNode,
    this.autofocus = false,
    this.autocorrect = true,
    this.enabled = true,
    this.smartQuotesType,
    this.smartDashesType,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedPlaceholder = placeholder ?? resolveResourceOrFail('hint');

    // Phase 3: Resolve optional TextStyle from resources
    final resolvedStyle = style ?? _resolveTextStyle('style');
    final resolvedPlaceholderStyle = placeholderStyle ?? _resolveTextStyle('placeholderStyle');

    return CupertinoSearchTextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onSuffixTap: onSuffixTap,
      style: resolvedStyle,
      placeholder: resolvedPlaceholder,
      placeholderStyle: resolvedPlaceholderStyle,
      decoration: decoration,
      backgroundColor: backgroundColor ?? resolveColorOrNull('backgroundColor'),
      borderRadius: borderRadius ?? _resolveBorderRadius('borderRadius') ?? const BorderRadius.all(Radius.circular(8.0)),
      padding: padding ?? resolveEdgeInsetsOrNull('padding') ?? const EdgeInsetsDirectional.fromSTEB(5.5, 8, 5.5, 8),
      itemColor: itemColor ?? resolveColorOrNull('itemColor') ?? CupertinoColors.secondaryLabel,
      itemSize: itemSize ?? resolveDoubleOrNull('itemSize') ?? 20.0,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      suffixMode: suffixMode,
      restorationId: restorationId,
      focusNode: focusNode,
      autofocus: autofocus,
      autocorrect: autocorrect,
      enabled: enabled,
      smartQuotesType: smartQuotesType,
      smartDashesType: smartDashesType,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
  }

  BorderRadius? _resolveBorderRadius(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderRadius(basePath, suffix);
  }
}

/// Tom wrapper for [CupertinoTimerPicker].
///
/// Duration/timer picker wheel. Auth for readonly/hidden.
class TomCupertinoTimerPicker extends TomInputBase {
  final CupertinoTimerPickerMode mode;
  final Duration initialTimerDuration;
  final int minuteInterval;
  final int secondInterval;
  final AlignmentGeometry alignment;
  final Color? backgroundColor;
  final double? itemExtent;
  final ValueChanged<Duration> onTimerDurationChanged;

  const TomCupertinoTimerPicker({
    super.key,
    super.tomId,
    super.tomGroup,
    this.mode = CupertinoTimerPickerMode.hms,
    this.initialTimerDuration = Duration.zero,
    this.minuteInterval = 1,
    this.secondInterval = 1,
    this.alignment = Alignment.center,
    this.backgroundColor,
    this.itemExtent,
    required this.onTimerDurationChanged,
  });

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoTimerPicker(
      mode: mode,
      initialTimerDuration: initialTimerDuration,
      minuteInterval: minuteInterval,
      secondInterval: secondInterval,
      alignment: alignment,
      backgroundColor: backgroundColor ?? resolveColorOrNull('backgroundColor'),
      itemExtent: itemExtent ?? resolveDoubleOrNull('itemExtent') ?? 32.0,
      onTimerDurationChanged: onTimerDurationChanged,
    );
  }
}

/// Tom wrapper for [Form].
///
/// Form container managing validation state. Auth can hide entire form sections.
class TomForm extends TomInputBase {
  final Widget child;
  final AutovalidateMode? autovalidateMode;
  final VoidCallback? onChanged;
  final bool? canPop;
  final PopInvokedWithResultCallback<Object?>? onPopInvokedWithResult;

  const TomForm({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.child,
    this.autovalidateMode,
    this.onChanged,
    this.canPop,
    this.onPopInvokedWithResult,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Form(
      autovalidateMode: autovalidateMode,
      onChanged: onChanged,
      canPop: canPop,
      onPopInvokedWithResult: onPopInvokedWithResult,
      child: child,
    );
  }
}

/// Tom wrapper for [InputDatePickerFormField].
///
/// Text-based date entry with format validation. Auth for readonly/hidden.
class TomInputDatePickerFormField extends TomInputBase {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime>? onDateSubmitted;
  final ValueChanged<DateTime>? onDateSaved;
  final SelectableDayPredicate? selectableDayPredicate;
  final String? errorFormatText;
  final String? errorInvalidText;
  final String? fieldHintText;
  final String? fieldLabelText;
  final TextInputType keyboardType;
  final bool autofocus;
  final bool acceptEmptyDate;
  final FocusNode? focusNode;

  const TomInputDatePickerFormField({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.onDateSubmitted,
    this.onDateSaved,
    this.selectableDayPredicate,
    this.errorFormatText,
    this.errorInvalidText,
    this.fieldHintText,
    this.fieldLabelText,
    this.keyboardType = TextInputType.datetime,
    this.autofocus = false,
    this.acceptEmptyDate = false,
    this.focusNode,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabelText = fieldLabelText ?? resolveResourceOrFail('label');
    final resolvedHintText = fieldHintText ?? resolveResourceOrFail('hint');
    final resolvedErrorFormat = errorFormatText ?? resolveResourceOrFail('errorFormat');
    final resolvedErrorInvalid = errorInvalidText ?? resolveResourceOrFail('errorInvalid');

    return InputDatePickerFormField(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      onDateSubmitted: onDateSubmitted,
      onDateSaved: onDateSaved,
      selectableDayPredicate: selectableDayPredicate,
      errorFormatText: resolvedErrorFormat,
      errorInvalidText: resolvedErrorInvalid,
      fieldHintText: resolvedHintText,
      fieldLabelText: resolvedLabelText,
      keyboardType: keyboardType,
      autofocus: autofocus,
      acceptEmptyDate: acceptEmptyDate,
      focusNode: focusNode,
    );
  }
}

/// Tom wrapper for [YearPicker].
///
/// Year selection widget. Auth for readonly/hidden.
class TomYearPicker extends TomInputBase {
  final DateTime currentDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;
  final DragStartBehavior dragStartBehavior;

  const TomYearPicker({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.currentDate,
    required this.firstDate,
    required this.lastDate,
    required this.selectedDate,
    required this.onChanged,
    this.dragStartBehavior = DragStartBehavior.start,
  });

  @override
  Widget buildContent(BuildContext context) {
    return YearPicker(
      currentDate: currentDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectedDate: selectedDate,
      onChanged: onChanged,
      dragStartBehavior: dragStartBehavior,
    );
  }
}

/// Tom wrapper for [CupertinoTextFormFieldRow].
///
/// Cupertino form row containing a text field with Form integration.
/// Auth for readonly/hidden; resources for placeholder.
class TomCupertinoTextFormFieldRow extends TomInputBase {
  final Widget? prefix;
  final EdgeInsetsGeometry? padding;
  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final BoxDecoration? decoration;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final bool autofocus;
  final bool readOnly;
  final bool? showCursor;
  final String obscuringCharacter;
  final bool obscureText;
  final bool autocorrect;
  final SmartDashesType? smartDashesType;
  final SmartQuotesType? smartQuotesType;
  final bool enableSuggestions;
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final GestureTapCallback? onTap;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldSetter<String>? onSaved;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final bool? enabled;
  final double? cursorWidth;
  final double? cursorHeight;
  final Color? cursorColor;
  final Brightness? keyboardAppearance;
  final EdgeInsets? scrollPadding;
  final bool enableInteractiveSelection;
  final TextSelectionControls? selectionControls;
  final ScrollPhysics? scrollPhysics;
  final Iterable<String>? autofillHints;
  final AutovalidateMode autovalidateMode;
  final String? placeholder;
  final TextStyle? placeholderStyle;
  final EditableTextContextMenuBuilder? contextMenuBuilder;
  final SpellCheckConfiguration? spellCheckConfiguration;
  final String? restorationId;

  const TomCupertinoTextFormFieldRow({
    super.key,
    super.tomId,
    super.tomGroup,
    this.prefix,
    this.padding,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.decoration,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.style,
    this.strutStyle,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.autofocus = false,
    this.readOnly = false,
    this.showCursor,
    this.obscuringCharacter = '•',
    this.obscureText = false,
    this.autocorrect = true,
    this.smartDashesType,
    this.smartQuotesType,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.maxLength,
    this.onChanged,
    this.onTap,
    this.onEditingComplete,
    this.onFieldSubmitted,
    this.onSaved,
    this.validator,
    this.inputFormatters,
    this.enabled,
    this.cursorWidth,
    this.cursorHeight,
    this.cursorColor,
    this.keyboardAppearance,
    this.scrollPadding,
    this.enableInteractiveSelection = true,
    this.selectionControls,
    this.scrollPhysics,
    this.autofillHints,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.placeholder,
    this.placeholderStyle,
    this.contextMenuBuilder,
    this.spellCheckConfiguration,
    this.restorationId,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedPlaceholder =
        placeholder ?? (tomId != null ? resolveResourceOrFail('hint') : null);

    // Phase 3: Resolve optional TextStyle from resources
    final resolvedStyle = style ?? _resolveTextStyle('style');
    final resolvedPlaceholderStyle = placeholderStyle ?? _resolveTextStyle('placeholderStyle');

    return CupertinoTextFormFieldRow(
      prefix: prefix,
      padding: padding ?? resolveEdgeInsetsOrNull('padding'),
      controller: controller,
      initialValue: initialValue,
      focusNode: focusNode,
      decoration: decoration,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      style: resolvedStyle,
      strutStyle: strutStyle,
      textDirection: textDirection,
      textAlign: textAlign,
      textAlignVertical: textAlignVertical,
      autofocus: autofocus,
      readOnly: readOnly,
      showCursor: showCursor,
      obscuringCharacter: obscuringCharacter,
      obscureText: obscureText,
      autocorrect: autocorrect,
      smartDashesType: smartDashesType,
      smartQuotesType: smartQuotesType,
      enableSuggestions: enableSuggestions,
      maxLines: maxLines,
      minLines: minLines,
      expands: expands,
      maxLength: maxLength,
      onChanged: onChanged,
      onTap: onTap,
      onEditingComplete: onEditingComplete,
      onFieldSubmitted: onFieldSubmitted,
      onSaved: onSaved,
      validator: validator,
      inputFormatters: inputFormatters,
      enabled: enabled,
      cursorWidth: cursorWidth ?? resolveDoubleOrNull('cursorWidth') ?? 2.0,
      cursorHeight: cursorHeight ?? resolveDoubleOrNull('cursorHeight'),
      cursorColor: cursorColor ?? resolveColorOrNull('cursorColor'),
      keyboardAppearance: keyboardAppearance,
      scrollPadding: scrollPadding ?? resolveEdgeInsetsOrNull('scrollPadding') ?? const EdgeInsets.all(20.0),
      enableInteractiveSelection: enableInteractiveSelection,
      selectionControls: selectionControls,
      scrollPhysics: scrollPhysics,
      autofillHints: autofillHints,
      autovalidateMode: autovalidateMode,
      placeholder: resolvedPlaceholder,
      placeholderStyle: resolvedPlaceholderStyle,
      contextMenuBuilder: contextMenuBuilder,
      spellCheckConfiguration: spellCheckConfiguration,
      restorationId: restorationId,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
  }
}

/// Tom wrapper for [DropdownMenuFormField].
///
/// DropdownMenu with Form integration. Auth for readonly;
/// resources for label/hint/helper/error texts.
class TomDropdownMenuFormField<T> extends TomInputBase {
  final bool enabled;
  final double? width;
  final double? menuHeight;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final String? label;
  final String? hintText;
  final String? helperText;
  final Widget? selectedTrailingIcon;
  final bool enableFilter;
  final bool enableSearch;
  final TextInputType? keyboardType;
  final TextStyle? textStyle;
  final TextAlign textAlign;
  final Object? inputDecorationTheme;
  final MenuStyle? menuStyle;
  final TextEditingController? controller;
  final T? initialSelection;
  final ValueChanged<T?>? onSelected;
  final FocusNode? focusNode;
  final bool? requestFocusOnTap;
  final EdgeInsetsGeometry? expandedInsets;
  final Offset? alignmentOffset;
  final FilterCallback<T>? filterCallback;
  final SearchCallback<T>? searchCallback;
  final List<DropdownMenuEntry<T>> dropdownMenuEntries;
  final List<TextInputFormatter>? inputFormatters;
  final DropdownMenuCloseBehavior closeBehavior;
  final int maxLines;
  final TextInputAction? textInputAction;
  final String? restorationId;
  final FormFieldSetter<T>? onSaved;
  final AutovalidateMode autovalidateMode;
  final FormFieldValidator<T>? validator;
  final String? forceErrorText;

  const TomDropdownMenuFormField({
    super.key,
    super.tomId,
    super.tomGroup,
    this.enabled = true,
    this.width,
    this.menuHeight,
    this.leadingIcon,
    this.trailingIcon,
    this.label,
    this.hintText,
    this.helperText,
    this.selectedTrailingIcon,
    this.enableFilter = false,
    this.enableSearch = true,
    this.keyboardType,
    this.textStyle,
    this.textAlign = TextAlign.start,
    this.inputDecorationTheme,
    this.menuStyle,
    this.controller,
    this.initialSelection,
    this.onSelected,
    this.focusNode,
    this.requestFocusOnTap,
    this.expandedInsets,
    this.alignmentOffset,
    this.filterCallback,
    this.searchCallback,
    required this.dropdownMenuEntries,
    this.inputFormatters,
    this.closeBehavior = DropdownMenuCloseBehavior.all,
    this.maxLines = 1,
    this.textInputAction,
    this.restorationId,
    this.onSaved,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.validator,
    this.forceErrorText,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = label ?? resolveResourceOrFail('label');
    final resolvedHint =
        hintText ?? (tomId != null ? resolveResourceOrFail('hint') : null);
    final resolvedHelper =
        helperText ?? (tomId != null ? resolveResourceOrFail('helper') : null);
    // Phase 3: Resolve optional TextStyle from resources
    final resolvedTextStyle = textStyle ?? _resolveTextStyle('textStyle');

    return DropdownMenuFormField<T>(
      enabled: enabled,
      width: width ?? resolveDoubleOrNull('width'),
      menuHeight: menuHeight ?? resolveDoubleOrNull('menuHeight'),
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      label: Text(resolvedLabel),
      hintText: resolvedHint,
      helperText: resolvedHelper,
      selectedTrailingIcon: selectedTrailingIcon,
      enableFilter: enableFilter,
      enableSearch: enableSearch,
      keyboardType: keyboardType,
      textStyle: resolvedTextStyle,
      textAlign: textAlign,
      inputDecorationTheme: inputDecorationTheme,
      menuStyle: menuStyle,
      controller: controller,
      initialSelection: initialSelection,
      onSelected: onSelected,
      focusNode: focusNode,
      requestFocusOnTap: requestFocusOnTap,
      expandedInsets: expandedInsets ?? resolveEdgeInsetsOrNull('expandedInsets'),
      alignmentOffset: alignmentOffset,
      filterCallback: filterCallback,
      searchCallback: searchCallback,
      dropdownMenuEntries: dropdownMenuEntries,
      inputFormatters: inputFormatters,
      closeBehavior: closeBehavior,
      maxLines: maxLines,
      textInputAction: textInputAction,
      restorationId: restorationId,
      onSaved: onSaved,
      autovalidateMode: autovalidateMode,
      validator: validator,
      forceErrorText: forceErrorText,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
  }
}
