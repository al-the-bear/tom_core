import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_construction_helpers.dart';
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

  // Pre-resolved resource values
  late final String _resolvedLabel;
  late final String? _resolvedHint;
  late final Color? _resolvedCursorColor;
  late final Color? _resolvedCursorErrorColor;
  late final double? _resolvedCursorHeight;
  late final double _resolvedCursorWidth;
  late final int? _resolvedMaxLines;
  late final int? _resolvedMinLines;
  late final int? _resolvedMaxLength;
  late final bool _resolvedAutofocus;
  late final bool _resolvedObscureText;
  late final bool _resolvedAutocorrect;
  late final bool _resolvedEnableSuggestions;
  late final bool _resolvedExpands;
  late final bool _resolvedEnabled;
  late final bool _resolvedReadOnly;
  late final bool? _resolvedShowCursor;
  late final String _resolvedObscuringCharacter;
  late final EdgeInsets _resolvedScrollPadding;
  late final bool? _resolvedEnableInteractiveSelection;
  late final String? _resolvedRestorationId;
  late final bool _resolvedScribbleEnabled;
  late final bool _resolvedEnableIMEPersonalizedLearning;
  late final bool _resolvedCanRequestFocus;
  late final TextStyle? _resolvedStyle;
  late final InputDecoration? _resolvedDecoration;
  late final ScrollPhysics? _resolvedScrollPhysics;
  late final StrutStyle? _resolvedStrutStyle;

  TomTextField({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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
    ValueChanged<String>? onChanged,
    VoidCallback? onEditingComplete,
    ValueChanged<String>? onSubmitted,
    AppPrivateCommandCallback? onAppPrivateCommand,
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
    GestureTapCallback? onTap,
    this.onTapAlwaysCalled = false,
    TapRegionCallback? onTapOutside,
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
    InputCounterWidgetBuilder? buildCounter,
  }) : onChanged = InScopeBuilder(scope: scope).wrap1n(onChanged),
       onEditingComplete = InScopeBuilder(scope: scope).wrap0n(onEditingComplete),
       onSubmitted = InScopeBuilder(scope: scope).wrap1n(onSubmitted),
       onAppPrivateCommand = InScopeBuilder(scope: scope).wrap2n(onAppPrivateCommand),
       onTap = InScopeBuilder(scope: scope).wrap0n(onTap),
       onTapOutside = InScopeBuilder(scope: scope).wrap1n(onTapOutside),
       buildCounter = buildCounter != null
           ? InScopeBuilder(scope: scope).wrapCounter(buildCounter)
           : null {
    _resolvedLabel = label ?? TomCtr.textOrFail(basePath, 'label');
    _resolvedHint = hint ?? (tomId != null ? TomCtr.textOrFail(basePath, 'hint') : null);
    _resolvedCursorColor = cursorColor ?? TomCtr.color(basePath, 'cursorColor');
    _resolvedCursorErrorColor = cursorErrorColor ?? TomCtr.color(basePath, 'cursorErrorColor');
    _resolvedCursorHeight = cursorHeight ?? TomCtr.doubleVal(basePath, 'cursorHeight');
    _resolvedCursorWidth = cursorWidth ?? TomCtr.doubleVal(basePath, 'cursorWidth') ?? 2.0;
    _resolvedMaxLines = maxLines ?? TomCtr.intVal(basePath, 'maxLines');
    _resolvedMinLines = minLines ?? TomCtr.intVal(basePath, 'minLines');
    _resolvedMaxLength = maxLength ?? TomCtr.intVal(basePath, 'maxLength');
    _resolvedAutofocus = TomCtr.boolVal(basePath, 'autofocus') ?? autofocus;
    _resolvedObscureText = TomCtr.boolVal(basePath, 'obscureText') ?? obscureText;
    _resolvedAutocorrect = TomCtr.boolVal(basePath, 'autocorrect') ?? autocorrect;
    _resolvedEnableSuggestions = TomCtr.boolVal(basePath, 'enableSuggestions') ?? enableSuggestions;
    _resolvedExpands = TomCtr.boolVal(basePath, 'expands') ?? expands;
    _resolvedEnabled = TomCtr.boolVal(basePath, 'enabled') ?? enabled;
    _resolvedReadOnly = TomCtr.boolVal(basePath, 'readOnly') ?? readOnly;
    _resolvedShowCursor = showCursor ?? TomCtr.boolVal(basePath, 'showCursor');
    _resolvedObscuringCharacter = obscuringCharacter ?? TomCtr.textOrNull(basePath, 'obscuringCharacter') ?? '•';
    _resolvedScrollPadding = TomCtr.edgeInsets(basePath, 'scrollPadding') ?? scrollPadding;
    _resolvedEnableInteractiveSelection = enableInteractiveSelection ?? TomCtr.boolVal(basePath, 'enableInteractiveSelection');
    _resolvedRestorationId = restorationId ?? TomCtr.textOrNull(basePath, 'restorationId');
    _resolvedScribbleEnabled = TomCtr.boolVal(basePath, 'scribbleEnabled') ?? scribbleEnabled;
    _resolvedEnableIMEPersonalizedLearning = TomCtr.boolVal(basePath, 'enableIMEPersonalizedLearning') ?? enableIMEPersonalizedLearning;
    _resolvedCanRequestFocus = TomCtr.boolVal(basePath, 'canRequestFocus') ?? canRequestFocus;
    _resolvedStyle = style ?? _resolveTextStyle();
    _resolvedDecoration = _resolveDecoration(_resolvedLabel, _resolvedHint);
    _resolvedScrollPhysics = scrollPhysics ?? _resolveScrollPhysics('scrollPhysics');
    _resolvedStrutStyle = strutStyle ?? _resolveStrutStyle('strutStyle');
  }

  @override
  Widget buildContent(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: _resolvedDecoration,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: _resolvedStyle,
      strutStyle: _resolvedStrutStyle,
      textAlign: textAlign,
      textAlignVertical: textAlignVertical,
      textDirection: textDirection,
      autofocus: _resolvedAutofocus,
      obscureText: _resolvedObscureText,
      obscuringCharacter: _resolvedObscuringCharacter,
      autocorrect: _resolvedAutocorrect,
      smartDashesType: smartDashesType,
      smartQuotesType: smartQuotesType,
      enableSuggestions: _resolvedEnableSuggestions,
      maxLines: _resolvedMaxLines,
      minLines: _resolvedMinLines,
      expands: _resolvedExpands,
      maxLength: _resolvedMaxLength,
      maxLengthEnforcement: maxLengthEnforcement,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onSubmitted: onSubmitted,
      onAppPrivateCommand: onAppPrivateCommand,
      inputFormatters: inputFormatters,
      enabled: _resolvedEnabled,
      ignorePointers: ignorePointers,
      readOnly: _resolvedReadOnly,
      showCursor: _resolvedShowCursor,
      cursorWidth: _resolvedCursorWidth,
      cursorHeight: _resolvedCursorHeight,
      cursorRadius: cursorRadius,
      cursorColor: _resolvedCursorColor,
      cursorErrorColor: _resolvedCursorErrorColor,
      selectionHeightStyle: selectionHeightStyle,
      selectionWidthStyle: selectionWidthStyle,
      keyboardAppearance: keyboardAppearance,
      scrollPadding: _resolvedScrollPadding,
      dragStartBehavior: dragStartBehavior,
      enableInteractiveSelection: _resolvedEnableInteractiveSelection,
      selectionControls: selectionControls,
      onTap: onTap,
      onTapAlwaysCalled: onTapAlwaysCalled,
      onTapOutside: onTapOutside,
      mouseCursor: mouseCursor,
      scrollController: scrollController,
      scrollPhysics: _resolvedScrollPhysics,
      autofillHints: autofillHints,
      clipBehavior: clipBehavior,
      restorationId: _resolvedRestorationId,
      scribbleEnabled: _resolvedScribbleEnabled,
      enableIMEPersonalizedLearning: _resolvedEnableIMEPersonalizedLearning,
      contentInsertionConfiguration: contentInsertionConfiguration,
      contextMenuBuilder: contextMenuBuilder,
      canRequestFocus: _resolvedCanRequestFocus,
      spellCheckConfiguration: spellCheckConfiguration,
      magnifierConfiguration: magnifierConfiguration,
      undoController: undoController,
      buildCounter: buildCounter,
    );
  }

  /// Phase 3: Resolves TextStyle from resources.
  TextStyle? _resolveTextStyle() {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, 'style');
  }

  /// Phase 3: Resolves InputDecoration from resources and merges with explicit values.
  InputDecoration _resolveDecoration(String resolvedLabel, String? resolvedHint) {

    // Start with explicit decoration or empty
    InputDecoration base = decoration ?? const InputDecoration();

    // Try to resolve InputDecoration from resources
    if (basePath != null) {
      final resourceDecoration =
          TomStyleResolvers.resolveInputDecoration(basePath!, 'decoration');
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
    if (basePath == null) return null;
    return TomStyleResolvers.resolveStrutStyle(basePath!, suffix);
  }

  ScrollPhysics? _resolveScrollPhysics(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveScrollPhysics(basePath!, suffix);
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

  // Pre-resolved resource values
  late final String _resolvedLabel;
  late final String? _resolvedHint;
  late final int? _resolvedMaxLines;
  late final int? _resolvedMinLines;
  late final int? _resolvedMaxLength;
  late final bool _resolvedAutofocus;
  late final bool _resolvedObscureText;
  late final bool _resolvedAutocorrect;
  late final String? _resolvedInitialValue;
  late final bool _resolvedEnabled;
  late final bool _resolvedReadOnly;
  late final TextStyle? _resolvedStyle;
  late final InputDecoration? _resolvedDecoration;

  TomTextFormField({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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
    ValueChanged<String>? onChanged,
    VoidCallback? onEditingComplete,
    ValueChanged<String>? onFieldSubmitted,
    FormFieldSetter<String>? onSaved,
    FormFieldValidator<String>? validator,
    this.initialValue,
    this.enabled = true,
    this.readOnly = false,
    this.autovalidateMode,
    this.label,
    this.hint,
  })  : onChanged = InScopeBuilder(scope: scope).wrap1n(onChanged),
        onEditingComplete = InScopeBuilder(scope: scope).wrap0n(onEditingComplete),
        onFieldSubmitted = InScopeBuilder(scope: scope).wrap1n(onFieldSubmitted),
        onSaved = InScopeBuilder(scope: scope).wrap1n(onSaved),
        validator = InScopeBuilder(scope: scope).wrap1n(validator) {
    _resolvedLabel = label ?? TomCtr.textOrFail(basePath, 'label');
    _resolvedHint = hint ?? (tomId != null ? TomCtr.textOrFail(basePath, 'hint') : null);
    _resolvedMaxLines = maxLines ?? TomCtr.intVal(basePath, 'maxLines');
    _resolvedMinLines = minLines ?? TomCtr.intVal(basePath, 'minLines');
    _resolvedMaxLength = maxLength ?? TomCtr.intVal(basePath, 'maxLength');
    _resolvedAutofocus = TomCtr.boolVal(basePath, 'autofocus') ?? autofocus;
    _resolvedObscureText = TomCtr.boolVal(basePath, 'obscureText') ?? obscureText;
    _resolvedAutocorrect = TomCtr.boolVal(basePath, 'autocorrect') ?? autocorrect;
    _resolvedInitialValue = initialValue ?? TomCtr.textOrNull(basePath, 'initialValue');
    _resolvedEnabled = TomCtr.boolVal(basePath, 'enabled') ?? enabled;
    _resolvedReadOnly = TomCtr.boolVal(basePath, 'readOnly') ?? readOnly;
    _resolvedStyle = style ?? _resolveTextStyle();
    _resolvedDecoration = _resolveDecoration(_resolvedLabel, _resolvedHint);
  }

  @override
  Widget buildContent(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: _resolvedDecoration,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: _resolvedStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      autofocus: _resolvedAutofocus,
      obscureText: _resolvedObscureText,
      autocorrect: _resolvedAutocorrect,
      maxLines: _resolvedMaxLines,
      minLines: _resolvedMinLines,
      maxLength: _resolvedMaxLength,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onFieldSubmitted: onFieldSubmitted,
      onSaved: onSaved,
      validator: validator,
      initialValue: _resolvedInitialValue,
      enabled: _resolvedEnabled,
      readOnly: _resolvedReadOnly,
      autovalidateMode: autovalidateMode,
    );
  }

  /// Phase 3: Resolves TextStyle from resources.
  TextStyle? _resolveTextStyle() {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, 'style');
  }

  /// Phase 3: Resolves InputDecoration from resources and merges with explicit values.
  InputDecoration _resolveDecoration(String resolvedLabel, String? resolvedHint) {

    // Start with explicit decoration or empty
    InputDecoration base = decoration ?? const InputDecoration();

    // Try to resolve InputDecoration from resources
    if (basePath != null) {
      final resourceDecoration =
          TomStyleResolvers.resolveInputDecoration(basePath!, 'decoration');
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

  // Pre-resolved resource values
  late final String? _resolvedHint;
  late final bool _resolvedAutoFocus;
  late final BoxConstraints? _resolvedConstraints;

  TomSearchBar({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.controller,
    this.focusNode,
    this.hintText,
    this.leading,
    this.trailing,
    ValueChanged<String>? onChanged,
    VoidCallback? onTap,
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
  })  : onChanged = InScopeBuilder(scope: scope).wrap1n(onChanged),
        onTap = InScopeBuilder(scope: scope).wrap0n(onTap) {
    _resolvedHint = hintText ?? (tomId != null ? TomCtr.textOrFail(basePath, 'hint') : null);
    _resolvedAutoFocus = TomCtr.boolVal(basePath, 'autoFocus') ?? autoFocus;
    _resolvedConstraints = constraints ?? _resolveBoxConstraints('constraints');
  }

  @override
  Widget buildContent(BuildContext context) {
    return SearchBar(
      controller: controller,
      focusNode: focusNode,
      hintText: _resolvedHint,
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
      constraints: _resolvedConstraints,
      autoFocus: _resolvedAutoFocus,
      textCapitalization: textCapitalization,
    );
  }

  BoxConstraints? _resolveBoxConstraints(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBoxConstraints(basePath!, suffix);
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

  TomAutocomplete({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.optionsBuilder,
    this.displayStringForOption = RawAutocomplete.defaultStringForOption,
    AutocompleteFieldViewBuilder fieldViewBuilder = _defaultFieldViewBuilder,
    AutocompleteOnSelected<T>? onSelected,
    AutocompleteOptionsViewBuilder<T>? optionsViewBuilder,
    this.optionsViewOpenDirection = OptionsViewOpenDirection.down,
    this.initialValue,
  }) : onSelected = InScopeBuilder(scope: scope).wrap1n(onSelected),
       fieldViewBuilder = InScopeBuilder(scope: scope).wrap4(fieldViewBuilder),
       optionsViewBuilder = optionsViewBuilder != null
           ? InScopeBuilder(scope: scope).wrap3(optionsViewBuilder)
           : null;

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

  // Pre-resolved resource values
  late final String? _resolvedHint;
  late final Color? _resolvedViewBackgroundColor;
  late final double? _resolvedViewElevation;
  late final Color? _resolvedViewSurfaceTintColor;
  late final Color? _resolvedDividerColor;
  late final TextStyle? _resolvedHeaderTextStyle;
  late final TextStyle? _resolvedHeaderHintStyle;

  TomSearchAnchor({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.isFullScreen = false,
    this.searchController,
    SearchAnchorChildBuilder? builder,
    required SuggestionsBuilder suggestionsBuilder,
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
  }) : builder = builder != null
           ? InScopeBuilder(scope: scope).wrap2(builder)
           : null,
       suggestionsBuilder = InScopeBuilder(scope: scope).wrap2(suggestionsBuilder) {
    _resolvedHint = viewHintText ?? (tomId != null ? TomCtr.textOrFail(basePath, 'hint') : null);
    _resolvedViewBackgroundColor = viewBackgroundColor ?? TomCtr.color(basePath, 'viewBackgroundColor');
    _resolvedViewElevation = viewElevation ?? TomCtr.doubleVal(basePath, 'viewElevation');
    _resolvedViewSurfaceTintColor = viewSurfaceTintColor ?? TomCtr.color(basePath, 'viewSurfaceTintColor');
    _resolvedDividerColor = dividerColor ?? TomCtr.color(basePath, 'dividerColor');
    _resolvedHeaderTextStyle = headerTextStyle ?? _resolveTextStyle('headerTextStyle');
    _resolvedHeaderHintStyle = headerHintStyle ?? _resolveTextStyle('headerHintStyle');
  }

  @override
  Widget buildContent(BuildContext context) {
    return SearchAnchor(
      isFullScreen: isFullScreen,
      searchController: searchController,
      builder: builder ??
          (BuildContext context, SearchController controller) {
            return SearchBar(
              controller: controller,
              hintText: _resolvedHint,
              onTap: () => controller.openView(),
              onChanged: (_) => controller.openView(),
            );
          },
      suggestionsBuilder: suggestionsBuilder,
      viewLeading: viewLeading,
      viewTrailing: viewTrailing,
      viewHintText: _resolvedHint,
      viewBackgroundColor: _resolvedViewBackgroundColor,
      viewElevation: _resolvedViewElevation,
      viewSurfaceTintColor: _resolvedViewSurfaceTintColor,
      viewSide: viewSide,
      viewShape: viewShape,
      headerTextStyle: _resolvedHeaderTextStyle,
      headerHintStyle: _resolvedHeaderHintStyle,
      dividerColor: _resolvedDividerColor,
      viewConstraints: viewConstraints,
      textCapitalization: textCapitalization,
    );
  }

  /// Phase 3: Resolves TextStyle from resources.
  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
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

  // Pre-resolved resource values
  late final Color _resolvedBackgroundCursorColor;
  late final Color? _resolvedSelectionColor;
  late final double? _resolvedCursorHeight;
  late final double _resolvedCursorWidth;
  late final int? _resolvedMaxLines;
  late final int? _resolvedMinLines;

  TomEditableText({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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
    SelectionChangedCallback? onSelectionChanged,
    ValueChanged<String>? onChanged,
    VoidCallback? onEditingComplete,
    ValueChanged<String>? onSubmitted,
    this.rendererIgnoresPointer = false,
    this.enableInteractiveSelection = true,
    this.clipBehavior = Clip.hardEdge,
  })  : onSelectionChanged = InScopeBuilder(scope: scope).wrap2n(onSelectionChanged),
        onChanged = InScopeBuilder(scope: scope).wrap1n(onChanged),
        onEditingComplete = InScopeBuilder(scope: scope).wrap0n(onEditingComplete),
        onSubmitted = InScopeBuilder(scope: scope).wrap1n(onSubmitted) {
    _resolvedBackgroundCursorColor = backgroundCursorColor ?? TomCtr.color(basePath, 'backgroundCursorColor') ?? Colors.grey;
    _resolvedSelectionColor = selectionColor ?? TomCtr.color(basePath, 'selectionColor');
    _resolvedCursorHeight = cursorHeight ?? TomCtr.doubleVal(basePath, 'cursorHeight');
    _resolvedCursorWidth = cursorWidth ?? TomCtr.doubleVal(basePath, 'cursorWidth') ?? 2.0;
    _resolvedMaxLines = maxLines ?? TomCtr.intVal(basePath, 'maxLines');
    _resolvedMinLines = minLines ?? TomCtr.intVal(basePath, 'minLines');
  }

  @override
  Widget buildContent(BuildContext context) {
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
      backgroundCursorColor: _resolvedBackgroundCursorColor,
      maxLines: _resolvedMaxLines,
      minLines: _resolvedMinLines,
      expands: expands,
      autofocus: autofocus,
      selectionColor: _resolvedSelectionColor,
      selectionControls: selectionControls,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      textAlign: textAlign,
      textDirection: textDirection,
      textScaler: textScaler,
      showCursor: showCursor,
      showSelectionHandles: showSelectionHandles,
      cursorWidth: _resolvedCursorWidth,
      cursorHeight: _resolvedCursorHeight,
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

  // Pre-resolved resource values
  late final String? _resolvedPlaceholder;
  late final EdgeInsetsGeometry _resolvedPadding;
  late final int? _resolvedMaxLines;
  late final int? _resolvedMinLines;
  late final int? _resolvedMaxLength;
  late final TextStyle? _resolvedStyle;
  late final TextStyle? _resolvedPlaceholderStyle;

  TomCupertinoTextField({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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
    ValueChanged<String>? onChanged,
    VoidCallback? onEditingComplete,
    ValueChanged<String>? onSubmitted,
    this.enabled = true,
    this.readOnly = false,
  })  : onChanged = InScopeBuilder(scope: scope).wrap1n(onChanged),
        onEditingComplete = InScopeBuilder(scope: scope).wrap0n(onEditingComplete),
        onSubmitted = InScopeBuilder(scope: scope).wrap1n(onSubmitted) {
    _resolvedPlaceholder = placeholder ?? (tomId != null ? TomCtr.textOrFail(basePath, 'hint') : null);
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding') ?? const EdgeInsets.all(7.0);
    _resolvedMaxLines = maxLines ?? TomCtr.intVal(basePath, 'maxLines');
    _resolvedMinLines = minLines ?? TomCtr.intVal(basePath, 'minLines');
    _resolvedMaxLength = maxLength ?? TomCtr.intVal(basePath, 'maxLength');
    _resolvedStyle = style ?? _resolveTextStyle('style');
    _resolvedPlaceholderStyle = placeholderStyle ?? _resolveTextStyle('placeholderStyle');
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      focusNode: focusNode,
      decoration: decoration,
      padding: _resolvedPadding,
      placeholder: _resolvedPlaceholder,
      placeholderStyle: _resolvedPlaceholderStyle,
      prefix: prefix,
      prefixMode: prefixMode,
      suffix: suffix,
      suffixMode: suffixMode,
      clearButtonMode: clearButtonMode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: _resolvedStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      autofocus: autofocus,
      obscureText: obscureText,
      autocorrect: autocorrect,
      maxLines: _resolvedMaxLines,
      minLines: _resolvedMinLines,
      maxLength: _resolvedMaxLength,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onSubmitted: onSubmitted,
      enabled: enabled,
      readOnly: readOnly,
    );
  }

  /// Phase 3: Resolves TextStyle from resources.
  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
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

  TomCalendarDatePicker({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required ValueChanged<DateTime> onDateChanged,
    this.currentDate,
    this.selectableDayPredicate,
  })  : onDateChanged = InScopeBuilder(scope: scope).wrap1(onDateChanged);

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

  // Pre-resolved resource values
  late final Color? _resolvedBackgroundColor;
  late final double _resolvedItemExtent;

  TomCupertinoDatePicker({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.mode = CupertinoDatePickerMode.dateAndTime,
    required ValueChanged<DateTime> onDateTimeChanged,
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
  })  : onDateTimeChanged = InScopeBuilder(scope: scope).wrap1(onDateTimeChanged) {
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedItemExtent = itemExtent ?? TomCtr.doubleVal(basePath, 'itemExtent') ?? 32.0;
  }

  @override
  Widget buildContent(BuildContext context) {
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
      backgroundColor: _resolvedBackgroundColor,
      showDayOfWeek: showDayOfWeek,
      itemExtent: _resolvedItemExtent,
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

  // Pre-resolved resource values
  late final String _resolvedPlaceholder;
  late final TextStyle? _resolvedStyle;
  late final TextStyle? _resolvedPlaceholderStyle;
  late final Color? _resolvedBackgroundColor;
  late final BorderRadius? _resolvedBorderRadius;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final Color? _resolvedItemColor;
  late final double? _resolvedItemSize;

  TomCupertinoSearchTextField({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.controller,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    VoidCallback? onSuffixTap,
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
  })  : onChanged = InScopeBuilder(scope: scope).wrap1n(onChanged),
        onSubmitted = InScopeBuilder(scope: scope).wrap1n(onSubmitted),
        onSuffixTap = InScopeBuilder(scope: scope).wrap0n(onSuffixTap) {
    _resolvedPlaceholder = placeholder ?? TomCtr.textOrFail(basePath, 'hint');
    _resolvedStyle = style ?? _resolveTextStyle('style');
    _resolvedPlaceholderStyle = placeholderStyle ?? _resolveTextStyle('placeholderStyle');
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedBorderRadius = borderRadius ?? _resolveBorderRadius('borderRadius');
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
    _resolvedItemColor = itemColor ?? TomCtr.color(basePath, 'itemColor');
    _resolvedItemSize = itemSize ?? TomCtr.doubleVal(basePath, 'itemSize');
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoSearchTextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onSuffixTap: onSuffixTap,
      style: _resolvedStyle,
      placeholder: _resolvedPlaceholder,
      placeholderStyle: _resolvedPlaceholderStyle,
      decoration: decoration,
      backgroundColor: _resolvedBackgroundColor,
      borderRadius: _resolvedBorderRadius ?? const BorderRadius.all(Radius.circular(8.0)),
      padding: _resolvedPadding ?? const EdgeInsetsDirectional.fromSTEB(5.5, 8, 5.5, 8),
      itemColor: _resolvedItemColor ?? CupertinoColors.secondaryLabel,
      itemSize: _resolvedItemSize ?? 20.0,
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
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }

  BorderRadius? _resolveBorderRadius(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderRadius(basePath!, suffix);
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

  // Pre-resolved resource values
  late final Color? _resolvedBackgroundColor;
  late final double? _resolvedItemExtent;

  TomCupertinoTimerPicker({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.mode = CupertinoTimerPickerMode.hms,
    this.initialTimerDuration = Duration.zero,
    this.minuteInterval = 1,
    this.secondInterval = 1,
    this.alignment = Alignment.center,
    this.backgroundColor,
    this.itemExtent,
    required ValueChanged<Duration> onTimerDurationChanged,
  })  : onTimerDurationChanged = InScopeBuilder(scope: scope).wrap1(onTimerDurationChanged) {
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedItemExtent = itemExtent ?? TomCtr.doubleVal(basePath, 'itemExtent');
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoTimerPicker(
      mode: mode,
      initialTimerDuration: initialTimerDuration,
      minuteInterval: minuteInterval,
      secondInterval: secondInterval,
      alignment: alignment,
      backgroundColor: _resolvedBackgroundColor,
      itemExtent: _resolvedItemExtent ?? 32.0,
      onTimerDurationChanged: onTimerDurationChanged,
    );
  }
}

/// Tom wrapper for [Form].
///
/// Form container managing validation state. Auth can hide entire form sections.
///
/// Named `TomFormClassic` to distinguish from the new forms-layer
/// [TomForm] (§5) which provides typed data binding and validation.
class TomFormClassic extends TomInputBase {
  final Widget child;
  final AutovalidateMode? autovalidateMode;
  final VoidCallback? onChanged;
  final bool? canPop;
  final PopInvokedWithResultCallback<Object?>? onPopInvokedWithResult;

  TomFormClassic({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.child,
    this.autovalidateMode,
    VoidCallback? onChanged,
    this.canPop,
    PopInvokedWithResultCallback<Object?>? onPopInvokedWithResult,
  })  : onChanged = InScopeBuilder(scope: scope).wrap0n(onChanged),
        onPopInvokedWithResult = InScopeBuilder(scope: scope).wrap2n(onPopInvokedWithResult);

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

  // Pre-resolved resource values
  late final String _resolvedLabelText;
  late final String _resolvedHintText;
  late final String _resolvedErrorFormat;
  late final String _resolvedErrorInvalid;

  TomInputDatePickerFormField({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    ValueChanged<DateTime>? onDateSubmitted,
    ValueChanged<DateTime>? onDateSaved,
    this.selectableDayPredicate,
    this.errorFormatText,
    this.errorInvalidText,
    this.fieldHintText,
    this.fieldLabelText,
    this.keyboardType = TextInputType.datetime,
    this.autofocus = false,
    this.acceptEmptyDate = false,
    this.focusNode,
  })  : onDateSubmitted = InScopeBuilder(scope: scope).wrap1n(onDateSubmitted),
        onDateSaved = InScopeBuilder(scope: scope).wrap1n(onDateSaved) {
    _resolvedLabelText = fieldLabelText ?? TomCtr.textOrFail(basePath, 'label');
    _resolvedHintText = fieldHintText ?? TomCtr.textOrFail(basePath, 'hint');
    _resolvedErrorFormat = errorFormatText ?? TomCtr.textOrFail(basePath, 'errorFormat');
    _resolvedErrorInvalid = errorInvalidText ?? TomCtr.textOrFail(basePath, 'errorInvalid');
  }

  @override
  Widget buildContent(BuildContext context) {
    return InputDatePickerFormField(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      onDateSubmitted: onDateSubmitted,
      onDateSaved: onDateSaved,
      selectableDayPredicate: selectableDayPredicate,
      errorFormatText: _resolvedErrorFormat,
      errorInvalidText: _resolvedErrorInvalid,
      fieldHintText: _resolvedHintText,
      fieldLabelText: _resolvedLabelText,
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

  TomYearPicker({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.currentDate,
    required this.firstDate,
    required this.lastDate,
    required this.selectedDate,
    required ValueChanged<DateTime> onChanged,
    this.dragStartBehavior = DragStartBehavior.start,
  })  : onChanged = InScopeBuilder(scope: scope).wrap1(onChanged);

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

  // Pre-resolved resource values
  late final String? _resolvedPlaceholder;
  late final TextStyle? _resolvedStyle;
  late final TextStyle? _resolvedPlaceholderStyle;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final double? _resolvedCursorWidth;
  late final double? _resolvedCursorHeight;
  late final Color? _resolvedCursorColor;
  late final EdgeInsets? _resolvedScrollPadding;

  TomCupertinoTextFormFieldRow({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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
    ValueChanged<String>? onChanged,
    GestureTapCallback? onTap,
    VoidCallback? onEditingComplete,
    ValueChanged<String>? onFieldSubmitted,
    FormFieldSetter<String>? onSaved,
    FormFieldValidator<String>? validator,
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
  })  : onChanged = InScopeBuilder(scope: scope).wrap1n(onChanged),
        onTap = InScopeBuilder(scope: scope).wrap0n(onTap),
        onEditingComplete = InScopeBuilder(scope: scope).wrap0n(onEditingComplete),
        onFieldSubmitted = InScopeBuilder(scope: scope).wrap1n(onFieldSubmitted),
        onSaved = InScopeBuilder(scope: scope).wrap1n(onSaved),
        validator = InScopeBuilder(scope: scope).wrap1n(validator) {
    _resolvedPlaceholder = placeholder ?? (tomId != null ? TomCtr.textOrFail(basePath, 'hint') : null);
    _resolvedStyle = style ?? _resolveTextStyle('style');
    _resolvedPlaceholderStyle = placeholderStyle ?? _resolveTextStyle('placeholderStyle');
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
    _resolvedCursorWidth = cursorWidth ?? TomCtr.doubleVal(basePath, 'cursorWidth');
    _resolvedCursorHeight = cursorHeight ?? TomCtr.doubleVal(basePath, 'cursorHeight');
    _resolvedCursorColor = cursorColor ?? TomCtr.color(basePath, 'cursorColor');
    _resolvedScrollPadding = scrollPadding ?? TomCtr.edgeInsets(basePath, 'scrollPadding');
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoTextFormFieldRow(
      prefix: prefix,
      padding: _resolvedPadding,
      controller: controller,
      initialValue: initialValue,
      focusNode: focusNode,
      decoration: decoration,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      style: _resolvedStyle,
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
      cursorWidth: _resolvedCursorWidth ?? 2.0,
      cursorHeight: _resolvedCursorHeight,
      cursorColor: _resolvedCursorColor,
      keyboardAppearance: keyboardAppearance,
      scrollPadding: _resolvedScrollPadding ?? const EdgeInsets.all(20.0),
      enableInteractiveSelection: enableInteractiveSelection,
      selectionControls: selectionControls,
      scrollPhysics: scrollPhysics,
      autofillHints: autofillHints,
      autovalidateMode: autovalidateMode,
      placeholder: _resolvedPlaceholder,
      placeholderStyle: _resolvedPlaceholderStyle,
      contextMenuBuilder: contextMenuBuilder,
      spellCheckConfiguration: spellCheckConfiguration,
      restorationId: restorationId,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
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

  // Pre-resolved resource values
  late final String _resolvedLabel;
  late final String? _resolvedHint;
  late final String? _resolvedHelper;
  late final TextStyle? _resolvedTextStyle;
  late final double? _resolvedWidth;
  late final double? _resolvedMenuHeight;
  late final EdgeInsetsGeometry? _resolvedExpandedInsets;

  TomDropdownMenuFormField({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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
    ValueChanged<T?>? onSelected,
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
    FormFieldSetter<T>? onSaved,
    this.autovalidateMode = AutovalidateMode.disabled,
    FormFieldValidator<T>? validator,
    this.forceErrorText,
  })  : onSelected = InScopeBuilder(scope: scope).wrap1n(onSelected),
        onSaved = InScopeBuilder(scope: scope).wrap1n(onSaved),
        validator = InScopeBuilder(scope: scope).wrap1n(validator) {
    _resolvedLabel = label ?? TomCtr.textOrFail(basePath, 'label');
    _resolvedHint = hintText ?? (tomId != null ? TomCtr.textOrFail(basePath, 'hint') : null);
    _resolvedHelper = helperText ?? (tomId != null ? TomCtr.textOrFail(basePath, 'helper') : null);
    _resolvedTextStyle = textStyle ?? _resolveTextStyle('textStyle');
    _resolvedWidth = width ?? TomCtr.doubleVal(basePath, 'width');
    _resolvedMenuHeight = menuHeight ?? TomCtr.doubleVal(basePath, 'menuHeight');
    _resolvedExpandedInsets = expandedInsets ?? TomCtr.edgeInsets(basePath, 'expandedInsets');
  }

  @override
  Widget buildContent(BuildContext context) {
    return DropdownMenuFormField<T>(
      enabled: enabled,
      width: _resolvedWidth,
      menuHeight: _resolvedMenuHeight,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      label: Text(_resolvedLabel),
      hintText: _resolvedHint,
      helperText: _resolvedHelper,
      selectedTrailingIcon: selectedTrailingIcon,
      enableFilter: enableFilter,
      enableSearch: enableSearch,
      keyboardType: keyboardType,
      textStyle: _resolvedTextStyle,
      textAlign: textAlign,
      inputDecorationTheme: inputDecorationTheme,
      menuStyle: menuStyle,
      controller: controller,
      initialSelection: initialSelection,
      onSelected: onSelected,
      focusNode: focusNode,
      requestFocusOnTap: requestFocusOnTap,
      expandedInsets: _resolvedExpandedInsets,
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
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }
}
