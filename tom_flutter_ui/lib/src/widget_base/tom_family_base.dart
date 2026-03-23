import 'package:flutter/widgets.dart';

import '../resource_auth/tom_auth_state.dart';
import 'tom_node_base.dart';
import 'tom_policy_node_base.dart';
import 'tom_widget_family.dart';

/// Base class for all Tom widgets that belong to a widget family.
///
/// Reports the widget's primary [family] and supports multi-family membership
/// via [families]. Extends [TomPolicyNodeBase] so authorization is always
/// enforced.
abstract class TomFamilyBase extends TomPolicyNodeBase {
  const TomFamilyBase({super.key, super.tomId, super.tomGroup});

  /// The primary widget family for this widget.
  TomWidgetFamily get family;

  /// All families this widget belongs to. Defaults to just [family].
  ///
  /// Override for multi-family widgets (e.g., a date picker that is both
  /// [TomWidgetFamily.formField] and [TomWidgetFamily.dateTimePicker]).
  Set<TomWidgetFamily> get families => {family};

  /// Whether this widget belongs to the given [type].
  bool isFamily(TomWidgetFamily type) => families.contains(type);
}

// ────────────────────────────────────────────────────────────────────────────
// Family branch base classes — one per family
// ────────────────────────────────────────────────────────────────────────────

/// Base for the Button family.
///
/// Button widgets trigger actions. They connect to the action system via
/// typed [ActionTrigger] callbacks and have no direct state binding.
abstract class TomButtonBase extends TomFamilyBase {
  const TomButtonBase({
    super.key,
    super.tomId,
    super.tomGroup,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.button;
}

/// Base for the Input family (single-line text inputs).
abstract class TomInputBase extends TomFamilyBase {
  const TomInputBase({
    super.key,
    super.tomId,
    super.tomGroup,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.input;
}

/// Base for the Select family (dropdowns, popup menus).
abstract class TomSelectBase extends TomFamilyBase {
  const TomSelectBase({
    super.key,
    super.tomId,
    super.tomGroup,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.select;
}

/// Base for the Toggle family (switches, checkboxes, radios).
abstract class TomToggleBase extends TomFamilyBase {
  const TomToggleBase({
    super.key,
    super.tomId,
    super.tomGroup,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.toggle;
}

/// Base for the Slider family.
abstract class TomSliderBase extends TomFamilyBase {
  const TomSliderBase({
    super.key,
    super.tomId,
    super.tomGroup,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.slider;
}

/// Base for the Container family (structural wrapper widgets).
///
/// Containers propagate their ID to descendants via [TomNodeScope],
/// enabling child widgets to resolve their full canonical path
/// (e.g., `c-shipping.w-street`). This is the key mechanism that
/// allows authorization and resource lookup to work hierarchically.
abstract class TomContainerBase extends TomFamilyBase {
  const TomContainerBase({
    super.key,
    super.tomId,
    super.tomGroup,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.container;

  @override
  String get idPrefix => 'c-';

  @override
  Widget build(BuildContext context) {
    final resourceKeyPath = resolveResourceBasePath(context);

    final authState = resourceKeyPath != null
        ? TomUIAuthorization.resolveAuth(resourceKeyPath)
        : TomAuthState.fullAccess;

    if (!authState.visible) return const SizedBox.shrink();

    Widget content;
    if (authState.readonly) {
      content = buildReadonly(context);
    } else {
      content = buildContent(context);
    }

    // Containers propagate their ID to descendants so child widgets
    // can build their full canonical path (e.g., c-panel.w-field).
    if (tomId != null) {
      return TomNodeScope(
        fullIdPath: resourceKeyPath,
        groupName: tomGroup,
        child: content,
      );
    }
    return content;
  }
}

/// Base for the Dialog family.
abstract class TomDialogBase extends TomFamilyBase {
  const TomDialogBase({
    super.key,
    super.tomId,
    super.tomGroup,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.dialog;
}

/// Base for the Table family (data tables, paginated tables).
abstract class TomTableBase extends TomFamilyBase {
  const TomTableBase({
    super.key,
    super.tomId,
    super.tomGroup,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.table;
}

/// Base for the Label family (text, rich text, selectable text).
abstract class TomLabelBase extends TomFamilyBase {
  const TomLabelBase({
    super.key,
    super.tomId,
    super.tomGroup,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.label;
}

/// Base for the Image family (icons, avatars, images).
abstract class TomImageBase extends TomFamilyBase {
  const TomImageBase({
    super.key,
    super.tomId,
    super.tomGroup,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.image;
}

/// Base for the Navigation family (tab bars, drawers, rails).
abstract class TomNavigationBase extends TomFamilyBase {
  const TomNavigationBase({
    super.key,
    super.tomId,
    super.tomGroup,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.navigation;
}

/// Base for the Progress family (indicators, spinners).
abstract class TomProgressBase extends TomFamilyBase {
  const TomProgressBase({
    super.key,
    super.tomId,
    super.tomGroup,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.progress;
}

/// Base for the Chip family (filter, choice, action chips).
abstract class TomChipBase extends TomFamilyBase {
  const TomChipBase({
    super.key,
    super.tomId,
    super.tomGroup,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.chip;
}

/// Base for the List family (list views, list tiles).
abstract class TomListBase extends TomFamilyBase {
  const TomListBase({
    super.key,
    super.tomId,
    super.tomGroup,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.list;
}

/// Base for the Tree family (tree views).
abstract class TomTreeBase extends TomFamilyBase {
  const TomTreeBase({
    super.key,
    super.tomId,
    super.tomGroup,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.tree;
}
