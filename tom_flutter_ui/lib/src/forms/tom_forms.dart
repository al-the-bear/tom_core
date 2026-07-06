// Phase 0a — data model and prerequisites
export 'tom_form.dart';
export 'tom_form_child_container.dart';
export 'validation/validation_result.dart';
export 'validation/form_validation_error.dart';
export 'validation/validators.dart';
export 'validation/validator_registry.dart';
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
// Wraps every concrete field's rendered widget so TomAuthorizable-aware
// consumers (e.g. ACL hide-unauthorized) can reach the field's auth state.
export 'fields/tom_field_widget_adapter.dart';

// Phase 1 — concrete string fields
export 'fields/tom_form_string_field.dart';

// Phase 2 — selection variants, list fields, boolean fields
export 'fields/tom_form_string_selection.dart';
export 'fields/tom_form_string_list_field.dart';
export 'fields/tom_form_bool_field.dart';

// Phase 2a — collections, master-detail, inline list editing
export 'list/tom_list_form.dart';
export 'list/tom_inline_list_form.dart';
export 'list/tom_expandable_list_form.dart';
export 'list/tom_master_detail_list_form.dart';
export 'list/tom_list_form_toolbar.dart';
export 'list/tom_list_row_move_buttons.dart';
export 'list/tom_reorder_handle.dart';
export 'widgets/tom_unsaved_changes_guard.dart';
export 'widgets/tom_error_view.dart';
export 'widgets/tom_row_error_strip.dart';

// Phase 3 — numeric, date/time, duration field types
export 'fields/tom_form_int_field.dart';
export 'fields/tom_form_double_field.dart';
export 'fields/tom_form_range_fields.dart';
export 'fields/tom_date_time_format.dart';
export 'fields/tom_form_date_time_fields.dart';
export 'fields/tom_form_duration_field.dart';

// Phase 4 — enum, object, search, lookup, file, nullable inputs
export 'fields/tom_form_int_list_field.dart';
export 'fields/tom_form_enum_object_fields.dart';
export 'fields/tom_form_search_lookup_fields.dart';
export 'fields/tom_form_file_field.dart';
export 'fields/tom_form_nullable_inputs.dart';

// Phase 5a — Cupertino style + string / bool / string-list concretes
export 'style/tom_cupertino_form_style.dart';
export 'fields/cupertino/tom_cupertino_form_string_fields.dart';
export 'fields/cupertino/tom_cupertino_form_bool_fields.dart';
export 'fields/cupertino/tom_cupertino_form_string_list_field.dart';

// Phase 5b — Cupertino numeric + date/time concretes
export 'fields/cupertino/tom_cupertino_form_numeric_fields.dart';
export 'fields/cupertino/tom_cupertino_form_date_time_fields.dart';

// Phase 5c — Cupertino enum/object, search/lookup, file, nullable concretes
export 'fields/cupertino/tom_cupertino_form_enum_object_fields.dart';
export 'fields/cupertino/tom_cupertino_form_search_lookup_fields.dart';
export 'fields/cupertino/tom_cupertino_form_file_field.dart';
export 'fields/cupertino/tom_cupertino_form_nullable_inputs.dart';

// Phase 5c — FormFieldFamily factory (Material vs Cupertino concrete picker)
export 'form_field_family.dart';
