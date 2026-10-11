import 'tom_policy_node_base.dart';

/// Base class for every Tom widget that belongs to a widget family.
///
/// A family is a behavioural role — button, input, list, dialog — and the
/// family a widget belongs to is the branch base it extends: a
/// [TomButtonBase] is a button, and `widget is TomButtonBase` is the question
/// a caller asks. The type hierarchy is the whole taxonomy; there is no
/// separate value to read, because nothing would read it. Extends
/// [TomPolicyNodeBase], so authorization is always enforced.
abstract class TomFamilyBase extends TomPolicyNodeBase {
  TomFamilyBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}

// ────────────────────────────────────────────────────────────────────────────
// Family branch base classes — one per family
// ────────────────────────────────────────────────────────────────────────────

/// Base for the Button family.
abstract class TomButtonBase extends TomFamilyBase {
  TomButtonBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}

/// Base for the Input family (single-line text inputs).
abstract class TomInputBase extends TomFamilyBase {
  TomInputBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}

/// Base for the Select family (dropdowns, popup menus).
abstract class TomSelectBase extends TomFamilyBase {
  TomSelectBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}

/// Base for the Toggle family (switches, checkboxes, radios).
abstract class TomToggleBase extends TomFamilyBase {
  TomToggleBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}

/// Base for the Slider family.
abstract class TomSliderBase extends TomFamilyBase {
  TomSliderBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}

/// Base for the Container family (structural wrapper widgets).
abstract class TomContainerBase extends TomFamilyBase {
  TomContainerBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}

/// Base for the Dialog family.
abstract class TomDialogBase extends TomFamilyBase {
  TomDialogBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}

/// Base for the Table family (data tables, paginated tables).
abstract class TomTableBase extends TomFamilyBase {
  TomTableBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}

/// Base for the Label family (text, rich text, selectable text).
abstract class TomLabelBase extends TomFamilyBase {
  TomLabelBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}

/// Base for the Image family (icons, avatars, images).
abstract class TomImageBase extends TomFamilyBase {
  TomImageBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}

/// Base for the Navigation family (tab bars, drawers, rails).
abstract class TomNavigationBase extends TomFamilyBase {
  TomNavigationBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}

/// Base for the Progress family (indicators, spinners).
abstract class TomProgressBase extends TomFamilyBase {
  TomProgressBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}

/// Base for the Chip family (filter, choice, action chips).
abstract class TomChipBase extends TomFamilyBase {
  TomChipBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}

/// Base for the List family (list views, list tiles).
abstract class TomListBase extends TomFamilyBase {
  TomListBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}

/// Base for the Tree family (tree views).
abstract class TomTreeBase extends TomFamilyBase {
  TomTreeBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}

/// Base for the Sliver family (sliver-based scrolling widgets).
abstract class TomSliverBase extends TomFamilyBase {
  TomSliverBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}

/// Base for the Animated family (implicit animations).
abstract class TomAnimatedBase extends TomFamilyBase {
  TomAnimatedBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}

/// Base for the Effect family (visual effects, filters, backdrops).
abstract class TomEffectBase extends TomFamilyBase {
  TomEffectBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}

/// Base for the Interaction family (gesture detectors, drag targets).
abstract class TomInteractionBase extends TomFamilyBase {
  TomInteractionBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}

/// Base for the Builder family (stream, future, value listenable builders).
abstract class TomBuilderBase extends TomFamilyBase {
  TomBuilderBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });
}
