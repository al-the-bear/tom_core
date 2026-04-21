// Phase 0a — data model and prerequisites
export 'tom_form.dart';
export 'tom_form_child_container.dart';
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

// Phase 2a — collections, master-detail, inline list editing
export 'list/tom_list_form.dart';
export 'widgets/tom_unsaved_changes_guard.dart';
export 'widgets/tom_error_view.dart';
export 'widgets/tom_master_detail_scaffold.dart';

// Phase 3 — numeric, date/time, duration field types
export 'fields/tom_form_int_field.dart';
export 'fields/tom_form_double_field.dart';
export 'fields/tom_form_range_fields.dart';
export 'fields/tom_form_date_time_fields.dart';
export 'fields/tom_form_duration_field.dart';

// Phase 4 — enum, object, search, lookup, file, nullable inputs
export 'fields/tom_form_int_list_field.dart';
export 'fields/tom_form_enum_object_fields.dart';
export 'fields/tom_form_search_lookup_fields.dart';
export 'fields/tom_form_file_field.dart';
export 'fields/tom_form_nullable_inputs.dart';
