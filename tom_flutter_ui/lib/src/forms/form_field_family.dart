/// Phase 5c — `FormFieldFamily` factory.
///
/// A small factory that lets callers construct a field by abstract type
/// while picking the concrete Material or Cupertino implementation at
/// runtime. Both families share the same abstract bases (`TomFormStringField`,
/// `TomFormEnumField<T>`, `TomFormFileField`, …), so a single declaration
/// can resolve to either side just by switching the family.
///
/// Designed for Phase 5c "Demo P" (family swap by breakpoint), but useful
/// anywhere a form needs to render different concrete classes from the
/// same field declaration.
///
/// Usage:
///
/// ```dart
/// final family = isNarrow
///     ? FormFieldFamily.cupertino
///     : FormFieldFamily.material;
///
/// final name = family.stringInput('user.name', '');
/// final age  = family.intInput('user.age', 0);
/// final dob  = family.datePicker(
///   'user.dob',
///   DateTime(2000, 1, 1),
///   firstDate: DateTime(1900),
///   lastDate: DateTime.now(),
/// );
/// ```
///
/// Each factory method exposes a sensible subset of constructor parameters
/// shared by both Material and Cupertino concretes. The returned type is
/// the abstract base, so callers code against `TomFormStringField` etc.
library;

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'fields/cupertino/tom_cupertino_form_bool_fields.dart';
import 'fields/cupertino/tom_cupertino_form_date_time_fields.dart';
import 'fields/cupertino/tom_cupertino_form_enum_object_fields.dart';
import 'fields/cupertino/tom_cupertino_form_file_field.dart';
import 'fields/cupertino/tom_cupertino_form_nullable_inputs.dart';
import 'fields/cupertino/tom_cupertino_form_numeric_fields.dart';
import 'fields/cupertino/tom_cupertino_form_search_lookup_fields.dart';
import 'fields/cupertino/tom_cupertino_form_string_fields.dart';
import 'fields/tom_form_bool_field.dart';
import 'fields/tom_form_date_time_fields.dart';
import 'fields/tom_form_double_field.dart';
import 'fields/tom_form_enum_object_fields.dart';
import 'fields/tom_form_file_field.dart';
import 'fields/tom_form_int_field.dart';
import 'fields/tom_form_nullable_bool_field.dart';
import 'fields/tom_form_nullable_inputs.dart';
import 'fields/tom_form_search_lookup_fields.dart';
import 'fields/tom_form_string_field.dart';
import 'selection/tom_selectable_source.dart';
import 'tom_form.dart';

/// Family identifier — picks Material or Cupertino concrete implementations.
enum FormFieldFamilyKind { material, cupertino }

/// Factory that constructs concrete field instances of either the Material
/// or Cupertino family while exposing the shared abstract types as the
/// return value.
///
/// Use the static [material] / [cupertino] singletons, or call the const
/// constructor if you need to compute the family at runtime:
///
/// ```dart
/// final family = FormFieldFamily(
///   isNarrow ? FormFieldFamilyKind.cupertino : FormFieldFamilyKind.material,
/// );
/// ```
class FormFieldFamily {
  /// Which family this factory resolves to.
  final FormFieldFamilyKind kind;

  const FormFieldFamily(this.kind);

  /// Material family — emits `TomForm…` concretes.
  static const FormFieldFamily material =
      FormFieldFamily(FormFieldFamilyKind.material);

  /// Cupertino family — emits `TomCupertinoForm…` concretes.
  static const FormFieldFamily cupertino =
      FormFieldFamily(FormFieldFamilyKind.cupertino);

  /// Convenience: `true` when this family resolves to Cupertino concretes.
  bool get isCupertino => kind == FormFieldFamilyKind.cupertino;

  // ---------------------------------------------------------------------
  // String input — TomFormStringField
  // ---------------------------------------------------------------------

  /// Plain text input. Returns the Material `TomFormStringInput` or the
  /// Cupertino `TomCupertinoFormStringInput` wrapped in their shared
  /// abstract base.
  TomFormStringField stringInput(
    String tomId,
    String initialValue, {
    String? labelTextOverride,
    String? hintTextOverride,
    String? descriptionTextOverride,
    int? maxLength,
    TomForm? form,
    bool obscureText = false,
    List<Object>? validators,
    bool autoValidate = true,
    TomAuthorizationGroup? tomGroup,
    TomAuthorizer? authorizer,
    TomUIStateController? uiStateController,
  }) {
    if (isCupertino) {
      return TomCupertinoFormStringInput(
        tomId,
        initialValue,
        labelTextOverride: labelTextOverride,
        hintTextOverride: hintTextOverride,
        descriptionTextOverride: descriptionTextOverride,
        maxLength: maxLength,
        form: form,
        obscureText: obscureText,
        validators: validators ?? const [],
        autoValidate: autoValidate,
        tomGroup: tomGroup,
        authorizer: authorizer,
        uiStateController: uiStateController,
      );
    }
    return TomFormStringInput(
      tomId,
      initialValue,
      labelTextOverride: labelTextOverride,
      hintTextOverride: hintTextOverride,
      descriptionTextOverride: descriptionTextOverride,
      maxLength: maxLength,
      form: form,
      obscureText: obscureText,
      validators: validators ?? const [],
      autoValidate: autoValidate,
      tomGroup: tomGroup,
      authorizer: authorizer,
      uiStateController: uiStateController,
    );
  }

  // ---------------------------------------------------------------------
  // Numeric inputs
  // ---------------------------------------------------------------------

  /// Integer text input.
  TomFormIntField intInput(
    String tomId,
    int initialValue, {
    String? labelTextOverride,
    String? hintTextOverride,
    String? descriptionTextOverride,
    TomForm? form,
    List<Object>? validators,
    bool autoValidate = true,
    TomAuthorizationGroup? tomGroup,
    TomAuthorizer? authorizer,
    TomUIStateController? uiStateController,
  }) {
    if (isCupertino) {
      return TomCupertinoFormIntInput(
        tomId,
        initialValue,
        labelTextOverride: labelTextOverride,
        hintTextOverride: hintTextOverride,
        descriptionTextOverride: descriptionTextOverride,
        form: form,
        validators: validators ?? const [],
        autoValidate: autoValidate,
        tomGroup: tomGroup,
        authorizer: authorizer,
        uiStateController: uiStateController,
      );
    }
    return TomFormIntInput(
      tomId,
      initialValue,
      labelTextOverride: labelTextOverride,
      hintTextOverride: hintTextOverride,
      descriptionTextOverride: descriptionTextOverride,
      form: form,
      validators: validators ?? const [],
      autoValidate: autoValidate,
      tomGroup: tomGroup,
      authorizer: authorizer,
      uiStateController: uiStateController,
    );
  }

  /// Decimal text input.
  TomFormDoubleField doubleInput(
    String tomId,
    double initialValue, {
    String? labelTextOverride,
    String? hintTextOverride,
    String? descriptionTextOverride,
    int? decimals,
    TomForm? form,
    List<Object>? validators,
    bool autoValidate = true,
    TomAuthorizationGroup? tomGroup,
    TomAuthorizer? authorizer,
    TomUIStateController? uiStateController,
  }) {
    if (isCupertino) {
      return TomCupertinoFormDoubleInput(
        tomId,
        initialValue,
        labelTextOverride: labelTextOverride,
        hintTextOverride: hintTextOverride,
        descriptionTextOverride: descriptionTextOverride,
        decimals: decimals,
        form: form,
        validators: validators ?? const [],
        autoValidate: autoValidate,
        tomGroup: tomGroup,
        authorizer: authorizer,
        uiStateController: uiStateController,
      );
    }
    return TomFormDoubleInput(
      tomId,
      initialValue,
      labelTextOverride: labelTextOverride,
      hintTextOverride: hintTextOverride,
      descriptionTextOverride: descriptionTextOverride,
      decimals: decimals,
      form: form,
      validators: validators ?? const [],
      autoValidate: autoValidate,
      tomGroup: tomGroup,
      authorizer: authorizer,
      uiStateController: uiStateController,
    );
  }

  // ---------------------------------------------------------------------
  // Boolean — switch surface
  // ---------------------------------------------------------------------

  /// Boolean switch. Material `Switch` vs Cupertino `CupertinoSwitch`.
  TomFormBoolField boolSwitch(
    String tomId,
    bool initialValue, {
    String? labelTextOverride,
    String? descriptionTextOverride,
    TomForm? form,
    List<Object>? validators,
    bool autoValidate = true,
    TomAuthorizationGroup? tomGroup,
    TomAuthorizer? authorizer,
    TomUIStateController? uiStateController,
  }) {
    if (isCupertino) {
      return TomCupertinoFormBoolSwitch(
        tomId,
        initialValue,
        labelTextOverride: labelTextOverride,
        descriptionTextOverride: descriptionTextOverride,
        form: form,
        validators: validators ?? const [],
        autoValidate: autoValidate,
        tomGroup: tomGroup,
        authorizer: authorizer,
        uiStateController: uiStateController,
      );
    }
    return TomFormBoolSwitch(
      tomId,
      initialValue,
      labelTextOverride: labelTextOverride,
      descriptionTextOverride: descriptionTextOverride,
      form: form,
      validators: validators ?? const [],
      autoValidate: autoValidate,
      tomGroup: tomGroup,
      authorizer: authorizer,
      uiStateController: uiStateController,
    );
  }

  /// Tristate boolean. Material renders an indeterminate `Checkbox`; the
  /// Cupertino family, which has no such control, renders a three-segment
  /// Off / — / On slider. Pass `tristate: false` to keep the nullable value
  /// type while making the control two-state.
  TomFormNullableBoolField nullableBoolToggle(
    String tomId,
    bool? initialValue, {
    bool? tristate,
    String? labelTextOverride,
    String? descriptionTextOverride,
    TomForm? form,
    List<Object>? validators,
    bool autoValidate = true,
    TomAuthorizationGroup? tomGroup,
    TomAuthorizer? authorizer,
    TomUIStateController? uiStateController,
  }) {
    if (isCupertino) {
      return TomCupertinoFormNullableBoolToggle(
        tomId,
        initialValue,
        tristateOverride: tristate,
        labelTextOverride: labelTextOverride,
        descriptionTextOverride: descriptionTextOverride,
        form: form,
        validators: validators ?? const [],
        autoValidate: autoValidate,
        tomGroup: tomGroup,
        authorizer: authorizer,
        uiStateController: uiStateController,
      );
    }
    return TomFormNullableBoolCheckbox(
      tomId,
      initialValue,
      tristateOverride: tristate,
      labelTextOverride: labelTextOverride,
      descriptionTextOverride: descriptionTextOverride,
      form: form,
      validators: validators ?? const [],
      autoValidate: autoValidate,
      tomGroup: tomGroup,
      authorizer: authorizer,
      uiStateController: uiStateController,
    );
  }

  // ---------------------------------------------------------------------
  // Date & time
  // ---------------------------------------------------------------------

  /// Date picker — Material calendar dialog vs Cupertino wheel sheet.
  TomFormDateField datePicker(
    String tomId,
    DateTime initialValue, {
    required DateTime firstDate,
    required DateTime lastDate,
    String? labelTextOverride,
    String? descriptionTextOverride,
    TomForm? form,
    List<Object>? validators,
    bool autoValidate = true,
    TomAuthorizationGroup? tomGroup,
    TomAuthorizer? authorizer,
    TomUIStateController? uiStateController,
  }) {
    if (isCupertino) {
      return TomCupertinoFormDatePicker(
        tomId,
        initialValue,
        firstDate: firstDate,
        lastDate: lastDate,
        labelTextOverride: labelTextOverride,
        descriptionTextOverride: descriptionTextOverride,
        form: form,
        validators: validators ?? const [],
        autoValidate: autoValidate,
        tomGroup: tomGroup,
        authorizer: authorizer,
        uiStateController: uiStateController,
      );
    }
    return TomFormDatePicker(
      tomId,
      initialValue,
      firstDate: firstDate,
      lastDate: lastDate,
      labelTextOverride: labelTextOverride,
      descriptionTextOverride: descriptionTextOverride,
      form: form,
      validators: validators ?? const [],
      autoValidate: autoValidate,
      tomGroup: tomGroup,
      authorizer: authorizer,
      uiStateController: uiStateController,
    );
  }

  /// Time-of-day picker — Material `showTimePicker` vs Cupertino wheel.
  TomFormTimeField timePicker(
    String tomId,
    TimeOfDay initialValue, {
    String? labelTextOverride,
    String? descriptionTextOverride,
    TomForm? form,
    List<Object>? validators,
    bool autoValidate = true,
    TomAuthorizationGroup? tomGroup,
    TomAuthorizer? authorizer,
    TomUIStateController? uiStateController,
  }) {
    if (isCupertino) {
      return TomCupertinoFormTimePicker(
        tomId,
        initialValue,
        labelTextOverride: labelTextOverride,
        descriptionTextOverride: descriptionTextOverride,
        form: form,
        validators: validators ?? const [],
        autoValidate: autoValidate,
        tomGroup: tomGroup,
        authorizer: authorizer,
        uiStateController: uiStateController,
      );
    }
    return TomFormTimePicker(
      tomId,
      initialValue,
      labelTextOverride: labelTextOverride,
      descriptionTextOverride: descriptionTextOverride,
      form: form,
      validators: validators ?? const [],
      autoValidate: autoValidate,
      tomGroup: tomGroup,
      authorizer: authorizer,
      uiStateController: uiStateController,
    );
  }

  // ---------------------------------------------------------------------
  // Enum / object pickers
  // ---------------------------------------------------------------------

  /// Single-select enum picker — Material `DropdownButton` vs Cupertino
  /// wheel sheet.
  TomFormEnumField<T> enumPicker<T>(
    String tomId,
    T initialValue, {
    required TomSelectableSource<T> source,
    String? labelTextOverride,
    String? descriptionTextOverride,
    TomForm? form,
    List<Object>? validators,
    bool autoValidate = true,
    TomAuthorizationGroup? tomGroup,
    TomAuthorizer? authorizer,
    TomUIStateController? uiStateController,
  }) {
    if (isCupertino) {
      return TomCupertinoFormEnumPicker<T>(
        tomId,
        initialValue,
        source: source,
        labelTextOverride: labelTextOverride,
        descriptionTextOverride: descriptionTextOverride,
        form: form,
        validators: validators ?? const [],
        autoValidate: autoValidate,
        tomGroup: tomGroup,
        authorizer: authorizer,
        uiStateController: uiStateController,
      );
    }
    return TomFormEnumDropdown<T>(
      tomId,
      initialValue,
      source: source,
      labelTextOverride: labelTextOverride,
      descriptionTextOverride: descriptionTextOverride,
      form: form,
      validators: validators ?? const [],
      autoValidate: autoValidate,
      tomGroup: tomGroup,
      authorizer: authorizer,
      uiStateController: uiStateController,
    );
  }

  /// Object dropdown / picker for arbitrary objects with a label resolver.
  TomFormObjectField<T> objectPicker<T>(
    String tomId,
    T initialValue, {
    required TomSelectableSource<T> source,
    String? labelTextOverride,
    String? descriptionTextOverride,
    TomForm? form,
    List<Object>? validators,
    bool autoValidate = true,
    TomAuthorizationGroup? tomGroup,
    TomAuthorizer? authorizer,
    TomUIStateController? uiStateController,
  }) {
    if (isCupertino) {
      return TomCupertinoFormObjectPicker<T>(
        tomId,
        initialValue,
        source: source,
        labelTextOverride: labelTextOverride,
        descriptionTextOverride: descriptionTextOverride,
        form: form,
        validators: validators ?? const [],
        autoValidate: autoValidate,
        tomGroup: tomGroup,
        authorizer: authorizer,
        uiStateController: uiStateController,
      );
    }
    return TomFormObjectDropdown<T>(
      tomId,
      initialValue,
      source: source,
      labelTextOverride: labelTextOverride,
      descriptionTextOverride: descriptionTextOverride,
      form: form,
      validators: validators ?? const [],
      autoValidate: autoValidate,
      tomGroup: tomGroup,
      authorizer: authorizer,
      uiStateController: uiStateController,
    );
  }

  // ---------------------------------------------------------------------
  // Search & lookup
  // ---------------------------------------------------------------------

  /// Autocomplete search input.
  TomFormSearchField<T> searchInput<T>(
    String tomId,
    T initialValue, {
    required TomSelectableSource<T> source,
    bool Function(String query, SelectableItem<T> item)? searchPredicate,
    String Function(T value)? labelOf,
    String? labelTextOverride,
    String? hintTextOverride,
    String? descriptionTextOverride,
    TomForm? form,
    List<Object>? validators,
    bool autoValidate = true,
    TomAuthorizationGroup? tomGroup,
    TomAuthorizer? authorizer,
    TomUIStateController? uiStateController,
  }) {
    if (isCupertino) {
      return TomCupertinoFormSearchInput<T>(
        tomId,
        initialValue,
        source: source,
        searchPredicate: searchPredicate,
        labelOf: labelOf,
        labelTextOverride: labelTextOverride,
        hintTextOverride: hintTextOverride,
        descriptionTextOverride: descriptionTextOverride,
        form: form,
        validators: validators ?? const [],
        autoValidate: autoValidate,
        tomGroup: tomGroup,
        authorizer: authorizer,
        uiStateController: uiStateController,
      );
    }
    return TomFormSearchInput<T>(
      tomId,
      initialValue,
      source: source,
      searchPredicate: searchPredicate,
      labelOf: labelOf,
      labelTextOverride: labelTextOverride,
      hintTextOverride: hintTextOverride,
      descriptionTextOverride: descriptionTextOverride,
      form: form,
      validators: validators ?? const [],
      autoValidate: autoValidate,
      tomGroup: tomGroup,
      authorizer: authorizer,
      uiStateController: uiStateController,
    );
  }

  /// Modal lookup. Material `showDialog` vs Cupertino modal sheet.
  TomFormLookupField<T> lookup<T>(
    String tomId,
    T initialValue, {
    required TomSelectableSource<T> source,
    String Function(T value)? labelOf,
    String? title,
    String? labelTextOverride,
    String? descriptionTextOverride,
    TomForm? form,
    List<Object>? validators,
    bool autoValidate = true,
    TomAuthorizationGroup? tomGroup,
    TomAuthorizer? authorizer,
    TomUIStateController? uiStateController,
  }) {
    if (isCupertino) {
      return TomCupertinoFormLookupSheet<T>(
        tomId,
        initialValue,
        source: source,
        labelOf: labelOf,
        sheetTitle: title,
        labelTextOverride: labelTextOverride,
        descriptionTextOverride: descriptionTextOverride,
        form: form,
        validators: validators ?? const [],
        autoValidate: autoValidate,
        tomGroup: tomGroup,
        authorizer: authorizer,
        uiStateController: uiStateController,
      );
    }
    return TomFormLookupDialog<T>(
      tomId,
      initialValue,
      source: source,
      labelOf: labelOf,
      dialogTitle: title,
      labelTextOverride: labelTextOverride,
      descriptionTextOverride: descriptionTextOverride,
      form: form,
      validators: validators ?? const [],
      autoValidate: autoValidate,
      tomGroup: tomGroup,
      authorizer: authorizer,
      uiStateController: uiStateController,
    );
  }

  // ---------------------------------------------------------------------
  // File upload
  // ---------------------------------------------------------------------

  /// File upload control. Material elevated button vs Cupertino filled
  /// button. Picking errors surface through Material's snackbar /
  /// Cupertino's alert dialog respectively.
  TomFormFileField fileUpload(
    String tomId,
    FileRef? initialValue, {
    required FilePicker picker,
    String? labelTextOverride,
    String? descriptionTextOverride,
    List<String>? allowedExtensions,
    int? maxSizeBytes,
    TomForm? form,
    List<Object>? validators,
    bool autoValidate = true,
    TomAuthorizationGroup? tomGroup,
    TomAuthorizer? authorizer,
    TomUIStateController? uiStateController,
  }) {
    if (isCupertino) {
      return TomCupertinoFormFileUpload(
        tomId,
        initialValue,
        picker: picker,
        labelTextOverride: labelTextOverride,
        descriptionTextOverride: descriptionTextOverride,
        allowedExtensions: allowedExtensions,
        maxSizeBytes: maxSizeBytes,
        form: form,
        validators: validators ?? const [],
        autoValidate: autoValidate,
        tomGroup: tomGroup,
        authorizer: authorizer,
        uiStateController: uiStateController,
      );
    }
    return TomFormFileUpload(
      tomId,
      initialValue,
      picker: picker,
      labelTextOverride: labelTextOverride,
      descriptionTextOverride: descriptionTextOverride,
      allowedExtensions: allowedExtensions,
      maxSizeBytes: maxSizeBytes,
      form: form,
      validators: validators ?? const [],
      autoValidate: autoValidate,
      tomGroup: tomGroup,
      authorizer: authorizer,
      uiStateController: uiStateController,
    );
  }

  // ---------------------------------------------------------------------
  // Nullable inputs — return TomField<T?> directly because the abstract
  // bases for these are TomField itself.
  // ---------------------------------------------------------------------

  /// Nullable text input. Empty text round-trips as `null`.
  TomField<String?> nStringInput(
    String tomId,
    String? initialValue, {
    String? labelTextOverride,
    String? hintTextOverride,
    String? descriptionTextOverride,
    int? maxLength,
    TomForm? form,
    bool obscureText = false,
    List<Object>? validators,
    bool autoValidate = true,
    TomAuthorizationGroup? tomGroup,
    TomAuthorizer? authorizer,
    TomUIStateController? uiStateController,
  }) {
    if (isCupertino) {
      return TomCupertinoFormNStringInput(
        tomId,
        initialValue,
        labelTextOverride: labelTextOverride,
        hintTextOverride: hintTextOverride,
        descriptionTextOverride: descriptionTextOverride,
        maxLength: maxLength,
        form: form,
        obscureText: obscureText,
        validators: validators ?? const [],
        autoValidate: autoValidate,
        tomGroup: tomGroup,
        authorizer: authorizer,
        uiStateController: uiStateController,
      );
    }
    return TomFormNStringInput(
      tomId,
      initialValue,
      labelTextOverride: labelTextOverride,
      hintTextOverride: hintTextOverride,
      descriptionTextOverride: descriptionTextOverride,
      maxLength: maxLength,
      form: form,
      obscureText: obscureText,
      validators: validators ?? const [],
      autoValidate: autoValidate,
      tomGroup: tomGroup,
      authorizer: authorizer,
      uiStateController: uiStateController,
    );
  }

  /// Nullable integer input.
  TomField<int?> nIntInput(
    String tomId,
    int? initialValue, {
    String? labelTextOverride,
    String? hintTextOverride,
    String? descriptionTextOverride,
    TomForm? form,
    List<Object>? validators,
    bool autoValidate = true,
    TomAuthorizationGroup? tomGroup,
    TomAuthorizer? authorizer,
    TomUIStateController? uiStateController,
  }) {
    if (isCupertino) {
      return TomCupertinoFormNIntInput(
        tomId,
        initialValue,
        labelTextOverride: labelTextOverride,
        hintTextOverride: hintTextOverride,
        descriptionTextOverride: descriptionTextOverride,
        form: form,
        validators: validators ?? const [],
        autoValidate: autoValidate,
        tomGroup: tomGroup,
        authorizer: authorizer,
        uiStateController: uiStateController,
      );
    }
    return TomFormNIntInput(
      tomId,
      initialValue,
      labelTextOverride: labelTextOverride,
      hintTextOverride: hintTextOverride,
      descriptionTextOverride: descriptionTextOverride,
      form: form,
      validators: validators ?? const [],
      autoValidate: autoValidate,
      tomGroup: tomGroup,
      authorizer: authorizer,
      uiStateController: uiStateController,
    );
  }

  /// Nullable double input.
  TomField<double?> nDoubleInput(
    String tomId,
    double? initialValue, {
    String? labelTextOverride,
    String? hintTextOverride,
    String? descriptionTextOverride,
    int? decimals,
    TomForm? form,
    List<Object>? validators,
    bool autoValidate = true,
    TomAuthorizationGroup? tomGroup,
    TomAuthorizer? authorizer,
    TomUIStateController? uiStateController,
  }) {
    if (isCupertino) {
      return TomCupertinoFormNDoubleInput(
        tomId,
        initialValue,
        labelTextOverride: labelTextOverride,
        hintTextOverride: hintTextOverride,
        descriptionTextOverride: descriptionTextOverride,
        decimals: decimals,
        form: form,
        validators: validators ?? const [],
        autoValidate: autoValidate,
        tomGroup: tomGroup,
        authorizer: authorizer,
        uiStateController: uiStateController,
      );
    }
    return TomFormNDoubleInput(
      tomId,
      initialValue,
      labelTextOverride: labelTextOverride,
      hintTextOverride: hintTextOverride,
      descriptionTextOverride: descriptionTextOverride,
      decimals: decimals,
      form: form,
      validators: validators ?? const [],
      autoValidate: autoValidate,
      tomGroup: tomGroup,
      authorizer: authorizer,
      uiStateController: uiStateController,
    );
  }

  /// Nullable date input.
  TomField<DateTime?> nDateInput(
    String tomId,
    DateTime? initialValue, {
    required DateTime firstDate,
    required DateTime lastDate,
    String? labelTextOverride,
    String? hintTextOverride,
    String? descriptionTextOverride,
    TomForm? form,
    List<Object>? validators,
    bool autoValidate = true,
    TomAuthorizationGroup? tomGroup,
    TomAuthorizer? authorizer,
    TomUIStateController? uiStateController,
  }) {
    if (isCupertino) {
      return TomCupertinoFormNDateInput(
        tomId,
        initialValue,
        firstDate: firstDate,
        lastDate: lastDate,
        labelTextOverride: labelTextOverride,
        hintTextOverride: hintTextOverride,
        descriptionTextOverride: descriptionTextOverride,
        form: form,
        validators: validators ?? const [],
        autoValidate: autoValidate,
        tomGroup: tomGroup,
        authorizer: authorizer,
        uiStateController: uiStateController,
      );
    }
    return TomFormNDateInput(
      tomId,
      initialValue,
      firstDate: firstDate,
      lastDate: lastDate,
      labelTextOverride: labelTextOverride,
      hintTextOverride: hintTextOverride,
      descriptionTextOverride: descriptionTextOverride,
      form: form,
      validators: validators ?? const [],
      autoValidate: autoValidate,
      tomGroup: tomGroup,
      authorizer: authorizer,
      uiStateController: uiStateController,
    );
  }
}
