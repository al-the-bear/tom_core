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
export 'style/tom_form_style.dart';
export 'style/tom_form_style_scope.dart';
export 'style/tom_breakpoint.dart';
export 'style/tom_color_tokens.dart';
export 'style/tom_theme_spec.dart';
export 'decoration/tom_field_anatomy.dart';
export 'decoration/tom_string_input_decoration_mixin.dart';
export 'decoration/tom_dropdown_decoration_mixin.dart';
export 'decoration/tom_generic_field_decoration_mixin.dart';
export 'decoration/tom_stub_decoration_mixins.dart';
export 'widgets/tom_form_error_banner.dart';
export 'widgets/tom_multi_observable_builder.dart';

// Phase 1 — concrete string fields
export 'fields/tom_form_string_field.dart';

// Phase 2 — selection variants, list fields, boolean fields
export 'fields/tom_form_string_selection.dart';
export 'fields/tom_form_string_list_field.dart';
export 'fields/tom_form_bool_field.dart';
