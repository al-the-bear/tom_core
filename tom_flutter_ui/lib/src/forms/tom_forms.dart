// Data model and prerequisites
export 'tom_form.dart';
export 'tom_form_child_container.dart';
export 'validation/validation_result.dart';
export 'validation/form_validation_error.dart';
export 'validation/validators.dart';
export 'validation/validator_registry.dart';
export 'selection/tom_selectable_source.dart';
export 'selection/static_selectable_source.dart';
export 'selection/tom_enum_selectable_source.dart';
export 'events/tom_form_event.dart';
export 'events/tom_form_event_listener.dart';
export 'events/tom_form_event_source.dart';
export 'events/tom_form_inspector.dart';

// Widget infrastructure
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

// Concrete string fields
export 'fields/tom_form_string_field.dart';

// Selection variants, list fields, boolean fields
export 'fields/tom_form_string_selection.dart';
export 'fields/tom_form_string_list_field.dart';
export 'fields/tom_form_bool_field.dart';
export 'fields/tom_form_nullable_bool_field.dart';

// Collections, master-detail, inline list editing
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

// Numeric, date/time, duration field types
export 'fields/tom_form_int_field.dart';
export 'fields/tom_form_double_field.dart';
export 'fields/tom_form_range_fields.dart';
export 'fields/tom_date_time_format.dart';
export 'fields/tom_form_date_time_fields.dart';
export 'fields/tom_form_duration_field.dart';

// Enum, object, search, lookup, file, nullable inputs
export 'fields/tom_form_int_list_field.dart';
export 'fields/tom_form_enum_object_fields.dart';
export 'fields/tom_form_search_lookup_fields.dart';
export 'fields/tom_form_file_field.dart';
export 'fields/tom_form_nullable_inputs.dart';

// File plumbing: the picked value, the platform-picker registry,
// the transfer state machine, the transfer UX and the wording all of them
// resolve. Usable on their own, not just through a file field.
export 'files/file_ref.dart';
export 'files/tom_file_labels.dart';
export 'files/tom_file_picker_registry.dart';
export 'files/tom_file_transfer_controller.dart';
export 'files/tom_file_transfer_indicator.dart';

// Cupertino style + string / bool / string-list concretes
export 'style/tom_cupertino_form_style.dart';
export 'fields/cupertino/tom_cupertino_form_string_fields.dart';
export 'fields/cupertino/tom_cupertino_form_bool_fields.dart';
export 'fields/cupertino/tom_cupertino_form_string_list_field.dart';

// Cupertino numeric + date/time concretes
export 'fields/cupertino/tom_cupertino_form_numeric_fields.dart';
export 'fields/cupertino/tom_cupertino_form_date_time_fields.dart';

// Cupertino enum/object, search/lookup, file, nullable concretes
export 'fields/cupertino/tom_cupertino_form_enum_object_fields.dart';
export 'fields/cupertino/tom_cupertino_form_search_lookup_fields.dart';
export 'fields/cupertino/tom_cupertino_form_file_field.dart';
export 'fields/cupertino/tom_cupertino_form_nullable_inputs.dart';

// FormFieldFamily factory (Material vs Cupertino concrete picker)
export 'form_field_family.dart';
