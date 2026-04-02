import 'package:flutter/widgets.dart';

import '../resource_auth/tom_auth_state.dart';
import '../resource_auth/tom_id_prefix.dart';
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
/// Containers propagate their ID to descendants via [TomNodeScope].
///
/// When [idScope] is `true` (identity container), the container's ID is
/// appended to the descendant path — child widgets see it in their
/// canonical path (e.g., `c-shipping.w-street`).
///
/// When [idScope] is `false` (layout container, default), the container
/// resolves its OWN resources and auth using its self-path, but does NOT
/// modify the descendant path. This is the key mechanism that keeps
/// identity paths stable under UI restructuring.
abstract class TomContainerBase extends TomFamilyBase {
  /// Whether this container contributes its ID to descendant paths.
  ///
  /// - `true` — identity container: ID appears in descendant paths.
  /// - `false` — layout container (default): ID is for own resources only.
  final bool idScope;

  const TomContainerBase({
    super.key,
    super.tomId,
    super.tomGroup,
    this.idScope = false,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.container;

  @override
  String get idPrefix => 'c-';

  @override
  Widget build(BuildContext context) {
    // Self-path: always includes own ID (for own resources and auth).
    final scope = TomNodeScope.of(context);
    final selfPath = tomId != null
        ? (scope?.selfPathForContainer(tomId!) ??
            TomIdPrefix.prefixed(TomIdPrefix.container, tomId!))
        : null;

    final authState = selfPath != null
        ? TomUIAuthorization.resolveAuth(selfPath)
        : TomAuthState.fullAccess;

    if (!authState.visible) return const SizedBox.shrink();

    Widget content;
    if (authState.readonly) {
      content = buildReadonly(context);
    } else {
      content = buildContent(context);
    }

    // Scope propagation: only include ID in descendant path if idScope is true.
    if (tomId != null) {
      return TomNodeScope.extend(
        context,
        containerId: tomId,
        containerIdScope: idScope,
        groupId: tomGroup,
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

/// Base for the Sliver family (sliver-based scrolling widgets).
abstract class TomSliverBase extends TomFamilyBase {
  const TomSliverBase({
    super.key,
    super.tomId,
    super.tomGroup,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.sliver;
}

/// Base for the Animated family (implicit animations).
abstract class TomAnimatedBase extends TomFamilyBase {
  const TomAnimatedBase({
    super.key,
    super.tomId,
    super.tomGroup,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.animated;
}

/// Base for the Effect family (visual effects, filters, backdrops).
abstract class TomEffectBase extends TomFamilyBase {
  const TomEffectBase({
    super.key,
    super.tomId,
    super.tomGroup,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.effect;
}

/// Base for the Interaction family (gesture detectors, drag targets).
abstract class TomInteractionBase extends TomFamilyBase {
  const TomInteractionBase({
    super.key,
    super.tomId,
    super.tomGroup,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.interaction;
}

/// Base for the Builder family (stream, future, value listenable builders).
abstract class TomBuilderBase extends TomFamilyBase {
  const TomBuilderBase({
    super.key,
    super.tomId,
    super.tomGroup,
  });

  @override
  TomWidgetFamily get family => TomWidgetFamily.builder;
}
