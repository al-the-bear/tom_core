import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../widget_base/tom_family_base.dart';

// =============================================================================
// Section II: Effect Widgets
// =============================================================================

/// Tom wrapper for [BackdropFilter].
///
/// Applies blur/filter to everything behind the child. Auth on filtered content region.
class TomBackdropFilter extends TomEffectBase {
  final ImageFilter filter;
  final BlendMode blendMode;
  final Widget? child;

  const TomBackdropFilter({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.filter,
    this.blendMode = BlendMode.srcOver,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return BackdropFilter(
      filter: filter,
      blendMode: blendMode,
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

  const TomColorFiltered({
    super.key,
    super.tomId,
    super.tomGroup,
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
  final BlendMode blendMode;
  final Widget? child;

  const TomShaderMask({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.shaderCallback,
    this.blendMode = BlendMode.modulate,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return ShaderMask(
      shaderCallback: shaderCallback,
      blendMode: blendMode,
      child: child,
    );
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

  const TomSelectableRegion({
    super.key,
    super.tomId,
    super.tomGroup,
    this.focusNode,
    required this.selectionControls,
    required this.child,
    this.onSelectionChanged,
    this.contextMenuBuilder,
    this.magnifierConfiguration = TextMagnifierConfiguration.disabled,
  });

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

  const TomSelectionArea({
    super.key,
    super.tomId,
    super.tomGroup,
    this.focusNode,
    this.selectionControls,
    this.contextMenuBuilder = _defaultContextMenuBuilder,
    this.magnifierConfiguration,
    this.onSelectionChanged,
    required this.child,
  });

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
  final ContentSensitivity sensitivity;
  final Widget child;

  const TomSensitiveContent({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.sensitivity,
    required this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SensitiveContent(
      sensitivity: sensitivity,
      child: child,
    );
  }
}
