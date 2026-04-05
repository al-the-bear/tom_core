import 'package:flutter/widgets.dart';

import '../resource_auth/tom_auth_state.dart';
import 'tom_policy_node_base.dart';
import 'tom_widget_family.dart';

/// Base class for all Tom widgets that belong to a widget family.
///
/// Reports the widget's primary [family] and supports multi-family membership
/// via [families]. Extends [TomPolicyNodeBase] so authorization is always
/// enforced.
abstract class TomFamilyBase extends TomPolicyNodeBase {
  TomFamilyBase({super.key, super.tomId, super.tomGroup, super.scope});

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
  TomButtonBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.button;
}

/// Base for the Input family (single-line text inputs).
abstract class TomInputBase extends TomFamilyBase {
  TomInputBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.input;
}

/// Base for the Select family (dropdowns, popup menus).
abstract class TomSelectBase extends TomFamilyBase {
  TomSelectBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.select;
}

/// Base for the Toggle family (switches, checkboxes, radios).
abstract class TomToggleBase extends TomFamilyBase {
  TomToggleBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.toggle;
}

/// Base for the Slider family.
abstract class TomSliderBase extends TomFamilyBase {
  TomSliderBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.slider;
}

/// Base for the Container family (structural wrapper widgets).
///
/// Containers resolve their own resources and authorization using their
/// [tomId] but do NOT create new scopes for child widgets. Scoping is
/// managed at higher levels via [TomScope].
abstract class TomContainerBase extends TomFamilyBase {
  TomContainerBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.container;

  @override
  Widget build(BuildContext context) {
    // Self-path: <scopePath>.<tomId>
    final selfPath = basePath;

    final authState = selfPath != null
        ? TomUIAuthorization.resolveAuth(selfPath)
        : TomAuthState.fullAccess;

    if (!authState.visible) return const SizedBox.shrink();

    if (authState.readonly) {
      return buildReadonly(context);
    }
    return buildContent(context);
  }
}

/// Base for the Dialog family.
abstract class TomDialogBase extends TomFamilyBase {
  TomDialogBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.dialog;
}

/// Base for the Table family (data tables, paginated tables).
abstract class TomTableBase extends TomFamilyBase {
  TomTableBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.table;
}

/// Base for the Label family (text, rich text, selectable text).
abstract class TomLabelBase extends TomFamilyBase {
  TomLabelBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.label;
}

/// Base for the Image family (icons, avatars, images).
abstract class TomImageBase extends TomFamilyBase {
  TomImageBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.image;
}

/// Base for the Navigation family (tab bars, drawers, rails).
abstract class TomNavigationBase extends TomFamilyBase {
  TomNavigationBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.navigation;
}

/// Base for the Progress family (indicators, spinners).
abstract class TomProgressBase extends TomFamilyBase {
  TomProgressBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.progress;
}

/// Base for the Chip family (filter, choice, action chips).
abstract class TomChipBase extends TomFamilyBase {
  TomChipBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.chip;
}

/// Base for the List family (list views, list tiles).
abstract class TomListBase extends TomFamilyBase {
  TomListBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.list;
}

/// Base for the Tree family (tree views).
abstract class TomTreeBase extends TomFamilyBase {
  TomTreeBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.tree;
}

/// Base for the Sliver family (sliver-based scrolling widgets).
abstract class TomSliverBase extends TomFamilyBase {
  TomSliverBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.sliver;
}

/// Base for the Animated family (implicit animations).
abstract class TomAnimatedBase extends TomFamilyBase {
  TomAnimatedBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.animated;
}

/// Base for the Effect family (visual effects, filters, backdrops).
abstract class TomEffectBase extends TomFamilyBase {
  TomEffectBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.effect;
}

/// Base for the Interaction family (gesture detectors, drag targets).
abstract class TomInteractionBase extends TomFamilyBase {
  TomInteractionBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.interaction;
}

/// Base for the Builder family (stream, future, value listenable builders).
abstract class TomBuilderBase extends TomFamilyBase {
  TomBuilderBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.builder;
}
