/// Tom Flutter UI — authorization-aware Flutter widgets, forms and layout.
///
/// The package supplies the Flutter half of the Tom stack: a widget kit whose
/// members carry a stable identity, resolve their colours, icons and labels
/// through a resource layer, and derive their enabled / visible / read-only
/// state from a four-state authorization model rather than from ad-hoc `if`
/// checks in build methods. It sits on the platform-neutral state, security and
/// resource primitives in `tom_core_kernel`.
///
/// Everything is exported from this one library, so `AclBuilder`, `TomForm` and
/// `TomAction` are all reachable from a single import:
///
/// ```dart
/// import 'package:tom_flutter_ui/tom_flutter_ui.dart';
/// ```
///
/// > **Work in progress — unstable API.** This package is under active
/// > development and not yet stable; the version number is a publishing counter
/// > and carries no promise about API maturity.
///
/// ## The units
///
/// | Unit | What it is | Start at |
/// | ---- | ---------- | -------- |
/// | `advanced_container_layout` | The **ACL** engine — a fluent, row-based layout builder for form-like grids, with responsive variants and authorization built in. | [AclBuilder], [Acl] |
/// | `widget_base` | The base chain and the identity / resource / authorization plumbing every Tom widget inherits. | [TomNodeBase], [TomFamilyBase] |
/// | `widgets` | The general widget kit — buttons, inputs, lists, dialogs, containers. | [TomElevatedButton], [TomTextField] |
/// | `forms` | The form and field runtime: typed observable fields, validation, layout separation. | [TomForm] |
/// | `actions` | The action runtime — business logic with typed context, authorization and undo. | [TomAction], [TomActionController] |
/// | `groups` | `tomGroup` collective visibility control over whole UI regions. | [TomWidgetMixin], [TomAuthorizationGroup] |
/// | `resource_auth` | Colour, icon and config resolution. | [TomUIColors], [TomUIIcons], [TomConfigProvider] |
/// | `theme` | Theming and style variants. | [TomTheme] |
/// | `custom` | Non-form custom widgets built on the same kit. | [TomEmptyState] |
/// | `kernel_types` | The one bridge to `tom_core_kernel`: every kernel type named in a public signature here. | [TomScope], [TomAuthState] |
///
/// ## Documentation
///
/// `doc/README.md` indexes the full set and explains its two tiers — **design
/// specifications** (the cross-cutting *why*) and **module references** (the
/// public API of one `lib/src/` module in isolation). The fastest way in is
/// `doc/tom_flutter_ui_user_guide.md`; the layout engine in particular is
/// covered by `doc/advanced_container_layout.md` (reference) and
/// `doc/acl_design_specification.md` (design).
library;

export 'src/actions/actions.dart';
export 'src/advanced_container_layout/advanced_container_layout.dart';
export 'src/custom/tom_custom_widgets.dart';
export 'src/forms/tom_forms.dart';
export 'src/groups/groups.dart';
export 'src/kernel_types.dart';
export 'src/resource_auth/resource_auth.dart';
export 'src/theme/theme.dart';
export 'src/widget_base/widget_base.dart';
export 'src/widgets/widgets.dart';
