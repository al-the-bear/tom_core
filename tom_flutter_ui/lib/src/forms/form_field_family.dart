/// A small factory that lets callers construct a field by abstract type
/// while picking the concrete Material or Cupertino implementation at
/// runtime. Both families share the same abstract bases (`TomFormStringField`,
/// `TomFormEnumField<T>`, `TomFormFileField`, …), so a single declaration
/// can resolve to either side just by switching the family.
///
/// Swapping the family by breakpoint is the motivating case, but the
/// factory is useful anywhere a form needs to render different concrete
/// classes from the same field declaration.
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
/// A method exists here **exactly when a field kind has a concrete on both
/// sides**. A one-sided kind cannot have one: the method would have to return
/// the same class whichever family it was asked for, which defeats the point.
/// The rule therefore reads in both directions — no method means the control
/// is genuinely Material-only or Cupertino-only, not that the factory has a
/// gap. Construct those from the catalogue directly.
/// `test/forms/form_field_family_completeness_test.dart` derives the
/// both-sided kinds from the catalogue and holds this rule in both directions.
///
/// Each factory method exposes a sensible subset of constructor parameters
/// shared by both Material and Cupertino concretes; where the two sides take
/// different extras, neither is offered here, because passing one would be
/// choosing a rendering. The returned type is the abstract base, so callers
/// code against `TomFormStringField` etc.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart' show DateTimeRange, TimeOfDay;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'fields/cupertino/tom_cupertino_form_bool_fields.dart';
import 'fields/cupertino/tom_cupertino_form_date_time_fields.dart';
import 'fields/cupertino/tom_cupertino_form_enum_object_fields.dart';
import 'fields/cupertino/tom_cupertino_form_file_field.dart';
import 'fields/cupertino/tom_cupertino_form_nullable_inputs.dart';
import 'fields/cupertino/tom_cupertino_form_numeric_fields.dart';
import 'fields/cupertino/tom_cupertino_form_search_lookup_fields.dart';
import 'fields/cupertino/tom_cupertino_form_string_fields.dart';
import 'fields/cupertino/tom_cupertino_form_string_list_field.dart';
import 'fields/tom_form_bool_field.dart';
import 'fields/tom_form_date_time_fields.dart';
import 'fields/tom_form_double_field.dart';
import 'fields/tom_form_duration_field.dart';
import 'fields/tom_form_enum_object_fields.dart';
import 'fields/tom_form_file_field.dart';
import 'fields/tom_form_int_field.dart';
import 'fields/tom_form_nullable_bool_field.dart';
import 'fields/tom_form_nullable_inputs.dart';
import 'fields/tom_form_search_lookup_fields.dart';
import 'fields/tom_form_string_field.dart';
import 'fields/tom_form_string_list_field.dart';
import 'fields/tom_form_string_selection.dart';
import 'files/tom_file_picker_registry.dart';
import 'selection/tom_enum_selectable_source.dart';
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
  static const FormFieldFamily material = FormFieldFamily(
    FormFieldFamilyKind.material,
  );

  /// Cupertino family — emits `TomCupertinoForm…` concretes.
  static const FormFieldFamily cupertino = FormFieldFamily(
    FormFieldFamilyKind.cupertino,
  );

  /// Convenience: `true` when this family resolves to Cupertino concretes.
  bool get isCupertino => kind == FormFieldFamilyKind.cupertino;

  // ---------------------------------------------------------------------
  // String input & selection — TomFormStringField
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

  /// Pick one string from a list of options — Material `DropdownButton`
  /// vs Cupertino wheel sheet. The string analogue of [enumPicker].
  TomFormStringField stringPicker(
    String tomId,
    String initialValue, {
    required TomSelectableSource<String> source,
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
      return TomCupertinoFormStringPicker(
        tomId,
        initialValue,
        source: source,
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
    return TomFormStringDropdown(
      tomId,
      initialValue,
      source: source,
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

  /// Pick one string from a short option set laid out inline — Material
  /// `SegmentedButton` vs `CupertinoSlidingSegmentedControl`. Suited to
  /// two or three options; use [stringPicker] beyond that.
  TomFormStringField stringSegmented(
    String tomId,
    String initialValue, {
    required TomSelectableSource<String> source,
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
      return TomCupertinoFormStringSegmented(
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
    return TomFormStringSegmented(
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

  /// Pick any number of strings — Material filter chips vs a Cupertino
  /// modal sheet of checked rows. The value is the selected list.
  TomFormStringListField stringMultiSelect(
    String tomId,
    List<String> initialValue, {
    required TomSelectableSource<String> source,
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
      return TomCupertinoFormStringListCheckedPicker(
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
    return TomFormStringFilterChips(
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

  /// Decimal input formatted as money. `locale` and `currencyCode` select
  /// the formatting; both families parse and format identically and differ
  /// only in the text field they wrap.
  TomFormDoubleField currencyInput(
    String tomId,
    double initialValue, {
    String? locale,
    String? currencyCode,
    String? labelTextOverride,
    String? hintTextOverride,
    String? descriptionTextOverride,
    double? minValue,
    double? maxValue,
    TomForm? form,
    List<Object>? validators,
    bool autoValidate = true,
    TomAuthorizationGroup? tomGroup,
    TomAuthorizer? authorizer,
    TomUIStateController? uiStateController,
  }) {
    if (isCupertino) {
      return TomCupertinoFormCurrencyDoubleInput(
        tomId,
        initialValue,
        locale: locale,
        currencyCode: currencyCode,
        labelTextOverride: labelTextOverride,
        hintTextOverride: hintTextOverride,
        descriptionTextOverride: descriptionTextOverride,
        minValue: minValue,
        maxValue: maxValue,
        form: form,
        validators: validators ?? const [],
        autoValidate: autoValidate,
        tomGroup: tomGroup,
        authorizer: authorizer,
        uiStateController: uiStateController,
      );
    }
    return TomFormCurrencyDoubleInput(
      tomId,
      initialValue,
      locale: locale,
      currencyCode: currencyCode,
      labelTextOverride: labelTextOverride,
      hintTextOverride: hintTextOverride,
      descriptionTextOverride: descriptionTextOverride,
      minValue: minValue,
      maxValue: maxValue,
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

  /// Boolean rendered as a two-segment Off / On control rather than a
  /// switch — Material `SegmentedButton` vs
  /// `CupertinoSlidingSegmentedControl`. Prefer it over [boolSwitch] where
  /// both states deserve a written label.
  TomFormBoolField boolToggle(
    String tomId,
    bool initialValue, {
    String? onLabelOverride,
    String? offLabelOverride,
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
      return TomCupertinoFormBoolToggle(
        tomId,
        initialValue,
        onLabelOverride: onLabelOverride,
        offLabelOverride: offLabelOverride,
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
    return TomFormBoolToggle(
      tomId,
      initialValue,
      onLabelOverride: onLabelOverride,
      offLabelOverride: offLabelOverride,
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

  /// Combined date-and-time picker. Material runs its date dialog then its
  /// time dialog; Cupertino offers a single `dateAndTime` wheel. The value
  /// is one `DateTime` either way.
  TomFormDateTimeField dateTimePicker(
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
      return TomCupertinoFormDateTimePicker(
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
    return TomFormDateTimePicker(
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

  /// Start/end date range — Material `showDateRangePicker` vs a Cupertino
  /// sheet holding one wheel per endpoint.
  TomFormDateRangeField dateRangePicker(
    String tomId,
    DateTimeRange initialValue, {
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
      return TomCupertinoFormDateRangePicker(
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
    return TomFormDateRangePicker(
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

  /// Duration entry. This is the pair whose two sides are least alike:
  /// Material types hours and minutes into text fields, Cupertino spins a
  /// `CupertinoTimerPicker`. Only the shared parameters are exposed here —
  /// construct the concrete directly for `maxHours` (Material) or
  /// `mode` / `minuteInterval` (Cupertino).
  TomFormDurationField durationPicker(
    String tomId,
    Duration initialValue, {
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
      return TomCupertinoFormDurationPicker(
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
    return TomFormDurationInput(
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

  /// Single-select enum picker whose option labels come from the text
  /// bundle — the resource-keyed form of [enumPicker].
  ///
  /// Resolves each option under `<scope>.<enumName>.<value>` via
  /// [TomEnumSelectableSource], so the picker carries no Dart-side label
  /// table and re-renders when the application switches locale. Prefer this
  /// over building a [StaticSelectableSource] of hardcoded labels.
  ///
  /// ```dart
  /// family.enumPickerFor('status', TodoStatus.open, values: TodoStatus.values);
  /// ```
  TomFormEnumField<E> enumPickerFor<E extends Enum>(
    String tomId,
    E initialValue, {
    required List<E> values,
    String? labelTextOverride,
    String? descriptionTextOverride,
    TomForm? form,
    List<Object>? validators,
    bool autoValidate = true,
    TomAuthorizationGroup? tomGroup,
    TomAuthorizer? authorizer,
    TomUIStateController? uiStateController,
  }) {
    return enumPicker<E>(
      tomId,
      initialValue,
      source: TomEnumSelectableSource<E>(values),
      labelTextOverride: labelTextOverride,
      descriptionTextOverride: descriptionTextOverride,
      form: form,
      validators: validators,
      autoValidate: autoValidate,
      tomGroup: tomGroup,
      authorizer: authorizer,
      uiStateController: uiStateController,
    );
  }

  /// Single-select enum laid out inline — Material `SegmentedButton` vs
  /// `CupertinoSlidingSegmentedControl`. The inline form of [enumPicker],
  /// for enums short enough that every option fits on one row.
  ///
  /// `T` is bound to `Object` here where [enumPicker] leaves it open:
  /// `CupertinoSlidingSegmentedControl` requires a non-nullable type
  /// argument, so the factory can only promise what both sides accept.
  TomFormEnumField<T> enumSegmented<T extends Object>(
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
      return TomCupertinoFormEnumSegmented<T>(
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
    return TomFormEnumSegmented<T>(
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
    required TomFilePicker picker,
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
  // File thumbnail
  // ---------------------------------------------------------------------

  /// File control that shows the file rather than describing it — a square
  /// preview of the file's own content, falling back to the file-kind icon
  /// for anything Flutter has no codec for.
  ///
  /// Two deliberate differences from [fileUpload]:
  ///
  ///  * `picker` is optional. A form built from a specification has no picker
  ///    to pass; it relies on the one the application registered, and a
  ///    `required` here would put that form out of reach.
  ///  * the transfer wiring is exposed. Without it a re-opened form could
  ///    never fetch the stored file's bytes, so the presentation would degrade
  ///    to an icon in exactly the case it exists for.
  ///
  /// `pickKind` defaults to [TomFilePickKind.image]: a thumbnail that opened a
  /// "choose any file" dialog would invite the one file it cannot show.
  TomFormFileField fileThumbnail(
    String tomId,
    FileRef? initialValue, {
    TomFilePicker? picker,
    TomFilePickKind pickKind = TomFilePickKind.image,
    TomFileTransferClient? transferClient,
    String? storageSlot,
    void Function(FileRef ref, Uint8List bytes)? onDownload,
    double thumbnailSize = 96.0,
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
      return TomCupertinoFormFileThumbnail(
        tomId,
        initialValue,
        picker: picker,
        pickKind: pickKind,
        transferClient: transferClient,
        storageSlot: storageSlot,
        onDownload: onDownload,
        thumbnailSize: thumbnailSize,
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
    return TomFormFileThumbnail(
      tomId,
      initialValue,
      picker: picker,
      pickKind: pickKind,
      transferClient: transferClient,
      storageSlot: storageSlot,
      onDownload: onDownload,
      thumbnailSize: thumbnailSize,
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
