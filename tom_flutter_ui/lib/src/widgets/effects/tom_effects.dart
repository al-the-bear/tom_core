import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_construction_helpers.dart';

// =============================================================================
// Section II: Effect Widgets
// =============================================================================

/// Tom wrapper for [BackdropFilter].
///
/// Applies blur/filter to everything behind the child. Auth on filtered content region.
class TomBackdropFilter extends TomEffectBase {
  final ImageFilter filter;
  final BlendMode? blendMode;
  final Widget? child;

  // Pre-resolved resource values
  late final BlendMode _resolvedBlendMode;

  TomBackdropFilter({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.filter,
    this.blendMode,
    this.child,
  }) {
    _resolvedBlendMode = blendMode ?? _resolveBlendMode(TomCtr.textOrNull(basePath, 'blendMode')) ?? BlendMode.srcOver;
  }

  @override
  Widget buildContent(BuildContext context) {
    return BackdropFilter(
      filter: filter,
      blendMode: _resolvedBlendMode,
      child: child,
    );
  }
}

/// Tom wrapper for [ColorFiltered].
///
/// Applies color matrix filter. Auth on color-filtered content.
class TomColorFiltered extends TomEffectBase {
  final ColorFilter colorFilter;
  final Widget? child;

  TomColorFiltered({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.colorFilter,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return ColorFiltered(
      colorFilter: colorFilter,
      child: child,
    );
  }
}

/// Tom wrapper for [ShaderMask].
///
/// Applies shader as mask on child. Auth on masked content.
class TomShaderMask extends TomEffectBase {
  final ShaderCallback shaderCallback;
  final BlendMode? blendMode;
  final Widget? child;

  // Pre-resolved resource values
  late final BlendMode _resolvedBlendMode;

  TomShaderMask({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.shaderCallback,
    this.blendMode,
    this.child,
  }) {
    _resolvedBlendMode = blendMode ?? _resolveBlendMode(TomCtr.textOrNull(basePath, 'blendMode')) ?? BlendMode.modulate;
  }

  @override
  Widget buildContent(BuildContext context) {
    return ShaderMask(
      shaderCallback: shaderCallback,
      blendMode: _resolvedBlendMode,
      child: child,
    );
  }
}

BlendMode? _resolveBlendMode(String? value) {
  switch (value?.toLowerCase()) {
    case 'clear':
      return BlendMode.clear;
    case 'src':
      return BlendMode.src;
    case 'dst':
      return BlendMode.dst;
    case 'srcover':
      return BlendMode.srcOver;
    case 'dstover':
      return BlendMode.dstOver;
    case 'srcin':
      return BlendMode.srcIn;
    case 'dstin':
      return BlendMode.dstIn;
    case 'srcout':
      return BlendMode.srcOut;
    case 'dstout':
      return BlendMode.dstOut;
    case 'srcatop':
      return BlendMode.srcATop;
    case 'dstatop':
      return BlendMode.dstATop;
    case 'xor':
      return BlendMode.xor;
    case 'plus':
      return BlendMode.plus;
    case 'modulate':
      return BlendMode.modulate;
    case 'screen':
      return BlendMode.screen;
    case 'overlay':
      return BlendMode.overlay;
    case 'darken':
      return BlendMode.darken;
    case 'lighten':
      return BlendMode.lighten;
    case 'colordodge':
      return BlendMode.colorDodge;
    case 'colorburn':
      return BlendMode.colorBurn;
    case 'hardlight':
      return BlendMode.hardLight;
    case 'softlight':
      return BlendMode.softLight;
    case 'difference':
      return BlendMode.difference;
    case 'exclusion':
      return BlendMode.exclusion;
    case 'multiply':
      return BlendMode.multiply;
    case 'hue':
      return BlendMode.hue;
    case 'saturation':
      return BlendMode.saturation;
    case 'color':
      return BlendMode.color;
    case 'luminosity':
      return BlendMode.luminosity;
    default:
      return null;
  }
}

/// Tom wrapper for [SelectableRegion].
///
/// Defines selectable text/widget region. Auth can restrict text selection on sensitive content.
class TomSelectableRegion extends TomEffectBase {
  final FocusNode? focusNode;
  final TextSelectionControls selectionControls;
  final Widget child;
  final ValueChanged<SelectedContent?>? onSelectionChanged;
  final SelectableRegionContextMenuBuilder? contextMenuBuilder;
  final TextMagnifierConfiguration magnifierConfiguration;

  TomSelectableRegion({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.focusNode,
    required this.selectionControls,
    required this.child,
    ValueChanged<SelectedContent?>? onSelectionChanged,
    this.contextMenuBuilder,
    this.magnifierConfiguration = TextMagnifierConfiguration.disabled,
  }) : onSelectionChanged = InScopeBuilder(scope: scope).wrap1n(onSelectionChanged);

  @override
  Widget buildContent(BuildContext context) {
    return SelectableRegion(
      focusNode: focusNode,
      selectionControls: selectionControls,
      onSelectionChanged: onSelectionChanged,
      contextMenuBuilder: contextMenuBuilder,
      magnifierConfiguration: magnifierConfiguration,
      child: child,
    );
  }
}

/// Tom wrapper for [SelectionArea].
///
/// Convenience wrapper for SelectableRegion. Auth on selectable content.
class TomSelectionArea extends TomEffectBase {
  final FocusNode? focusNode;
  final TextSelectionControls? selectionControls;
  final SelectableRegionContextMenuBuilder? contextMenuBuilder;
  final TextMagnifierConfiguration? magnifierConfiguration;
  final ValueChanged<SelectedContent?>? onSelectionChanged;
  final Widget child;

  TomSelectionArea({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.focusNode,
    this.selectionControls,
    this.contextMenuBuilder = _defaultContextMenuBuilder,
    this.magnifierConfiguration,
    ValueChanged<SelectedContent?>? onSelectionChanged,
    required this.child,
  }) : onSelectionChanged = InScopeBuilder(scope: scope).wrap1n(onSelectionChanged);

  static Widget _defaultContextMenuBuilder(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    return AdaptiveTextSelectionToolbar.selectableRegion(
      selectableRegionState: selectableRegionState,
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    return SelectionArea(
      focusNode: focusNode,
      selectionControls: selectionControls,
      contextMenuBuilder: contextMenuBuilder,
      magnifierConfiguration: magnifierConfiguration,
      onSelectionChanged: onSelectionChanged,
      child: child,
    );
  }
}

/// Tom wrapper for [SensitiveContent].
///
/// Flags content as sensitive to OS. Auth on sensitive content;
/// natural fit for auth-controlled sensitivity.
class TomSensitiveContent extends TomEffectBase {
  final ContentSensitivity? sensitivity;
  final Widget child;

  // Pre-resolved resource values
  late final ContentSensitivity _resolvedSensitivity;

  TomSensitiveContent({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.sensitivity,
    required this.child,
  }) {
    _resolvedSensitivity = sensitivity ?? _resolveContentSensitivity(TomCtr.textOrNull(basePath, 'sensitivity')) ?? ContentSensitivity.autoSensitive;
  }

  @override
  Widget buildContent(BuildContext context) {
    return SensitiveContent(
      sensitivity: _resolvedSensitivity,
      child: child,
    );
  }
}

ContentSensitivity? _resolveContentSensitivity(String? value) {
  switch (value?.toLowerCase()) {
    case 'auto':
    case 'autosensitive':
      return ContentSensitivity.autoSensitive;
    case 'sensitive':
      return ContentSensitivity.sensitive;
    case 'notsensitive':
      return ContentSensitivity.notSensitive;
    default:
      return null;
  }
}
