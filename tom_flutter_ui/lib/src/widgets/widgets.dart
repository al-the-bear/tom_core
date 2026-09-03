/// The general widget kit — 299 types across 20 sub-folders.
///
/// These are the non-form widgets: buttons, inputs, containers, tables,
/// toggles, dialogs and the rest. 290 of the 299 are thin wrappers that add
/// the Tom surface — identity, resource path, authorization — to a Flutter
/// widget and otherwise stay out of the way; 273 of those get it by
/// extending their family base class, the remaining 17 by mixing it in.
/// Nothing here re-implements Flutter behaviour, so a wrapper reads as its
/// Flutter original plus a `tomId`.
///
/// Read in this order:
/// - [TomElevatedButton] — a representative wrapper, and the shortest
///   route to seeing what the surface adds.
/// - [TomTextField] — the same, for an input, where the authorization
///   states (`read`, `disabled`) actually change what renders.
///
/// The sub-folders are the navigation: `buttons/`, `inputs/`,
/// `containers/`, `tables/`, `toggles/`, `dialogs/` and so on, each with
/// its own barrel.
///
/// Prose: `doc/widgets.md`.
library;

export 'animated/tom_animated.dart';
export 'builders/tom_builders.dart';
export 'buttons/tom_buttons.dart';
export 'chips/tom_chips.dart';
export 'containers/acl/tom_acl.dart';
export 'containers/tom_containers.dart';
export 'dialogs/tom_dialogs.dart';
export 'dialogs/tom_messenger.dart';
export 'effects/tom_effects.dart';
export 'images/tom_images.dart';
export 'inputs/tom_inputs.dart';
export 'interactions/tom_interactions.dart';
export 'labels/tom_labels.dart';
export 'lists/tom_lists.dart';
export 'navigation/tom_navigation.dart';
export 'navigation/tom_page_route.dart';
export 'progress/tom_progress.dart';
export 'selects/tom_selects.dart';
export 'sliders/tom_sliders.dart';
export 'slivers/tom_slivers.dart';
export 'tables/tom_tables.dart';
export 'toggles/tom_toggles.dart';
export 'trees/tom_trees.dart';
