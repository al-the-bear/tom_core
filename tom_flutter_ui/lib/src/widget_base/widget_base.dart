/// The foundation every Tom widget stands on.
///
/// A Tom widget is a Flutter widget plus exactly four things: an identity
/// (`tomId`), an optional group membership, a resource path derived from the
/// active scope, and an authorization state that can hide, disable or
/// read-only the widget before it ever builds. This unit supplies all four,
/// so that neither the general widget kit nor the form system has to
/// re-implement identity, resource lookup or the authorization gate.
///
/// Read in this order:
/// - [TomNodeBase] — the root of the chain; carries the identity and the
///   group, and resolves the resource path.
/// - [TomPolicyNodeBase] — adds the authorization gate. Every Tom widget
///   passes through it, which is why authorization cannot be forgotten.
/// - [TomFamilyBase] — adds the widget's behavioural family, fixed by each
///   of the 20 branch bases ([TomButtonBase], [TomInputBase], …).
///
/// Also here: [TomWidgetSurface], the interface naming those four
/// contributions; [TomWidgetFamily], the enum of behavioural roles a widget
/// reports (not a base class — the chain above is); [TomCtr], the single
/// entry point for resource resolution; and [TomScreenElementsProvider], by
/// which a screen declares its widgets as typed fields.
///
/// Prose: `doc/widget_base.md`.
library;

export 'tom_auth_layers.dart';
export 'tom_construction_helpers.dart';
export 'tom_family_base.dart';
export 'tom_node_base.dart';
export 'tom_policy_node_base.dart';
export 'tom_scope_path.dart';
export 'tom_scope_widgets.dart';
export 'tom_screen_elements_provider.dart';
export 'tom_style_resolvers.dart';
export 'tom_widget_family.dart';
export 'tom_widget_surface.dart';
