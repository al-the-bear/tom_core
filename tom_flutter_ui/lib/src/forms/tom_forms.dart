// Phase 0a — data model and prerequisites
export 'tom_form.dart';
export 'validation/validation_result.dart';
export 'validation/form_validation_error.dart';
export 'validation/validators.dart';
export 'selection/tom_selectable_source.dart';
export 'selection/static_selectable_source.dart';
export 'events/tom_form_event.dart';
export 'events/tom_form_event_listener.dart';
export 'events/tom_form_event_source.dart';
export 'events/tom_form_inspector.dart';

// Phase 0b — widget infrastructure
export 'style/form_style_enums.dart';
// New canonical style system (Phase 2 — shipped unused).
export 'style/tom_form_style.dart';
export 'style/tom_form_style_scope.dart';
// Legacy style system — still used by existing fields until Phase 3.
export 'style/tom_form_style_legacy.dart';
export 'style/tom_form_style_scope_legacy.dart';
export 'decoration/tom_field_decoration_mixin_legacy.dart';
export 'widgets/tom_form_error_banner.dart';
export 'widgets/tom_multi_observable_builder.dart';

// Phase 1 — concrete string fields
export 'fields/tom_form_string_field.dart';
