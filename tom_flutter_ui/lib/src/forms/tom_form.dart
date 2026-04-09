import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../widget_base/tom_construction_helpers.dart';
import '../widget_base/tom_screen_elements_provider.dart';

@tomReflector
abstract class TomForm extends TomClass implements TomScreenElementsProvider {
  /// The scope for this form's resource/authorization lookups.
  @override
  late final TomScope scope;

  /// The scope path as a string (convenience getter).
  String get scopePath => scope.getScopePath();

  late final String formId;
  late final TomForm? parentForm;
  late final Map<String, TomField> fields = {};

  TomForm({required this.formId, this.parentForm}) {
    scope = TomScope.current;
    getMembers().entries.where((entry) => entry.value is TomField).forEach((
      entry,
    ) {
      fields[entry.key] = entry.value as TomField;
    });
  }

  @override
  void prepareForSelfObservation() {
    TomScope.withScope(formId, () => createFormElements());
  }

  void createFormElements();

  List<Widget> getFields() {
    return fields.values.map((field) => field.getField()).toList();
  }

  Widget getField(String name) {
    return fields[name]!.getField();
  }

  bool validate() {
    bool valid = true;
    for (var element in fields.values) {
      valid = element.validate() && valid;
    }
    return valid;
  }

  Map<String, String?> errors() {
    Map<String, String?> result = {};
    for (var element in fields.values) {
      result[element.fieldName] = element.errorText;
    }
    return result;
  }

  Map<String, Object> save() {
    Map<String, Object> result = {};
    mute();
    for (var element in fields.values) {
      result[element.fieldName] = element.save();
    }
    unmute();
    return result;
  }
}

abstract class TomField<T> extends TomObject<T> {

  TomField(
    this.fieldName,
    this.initialValue, {
    this.form,
    this.obscureText = false,
  }) : super(initialValue) {
    scope = TomScope.current.getScopePath();
  }

  late String scope;
  String fieldName;
  TomForm? form;
  T initialValue;
  bool obscureText;

  bool validate();

  T save();

  String? get errorText;

  Widget getField();

}

/// Base class for text-based form fields with TextEditingController support.
///
/// Individual [InputDecoration] parameters (e.g. [labelText], [helperText],
/// [prefixIcon]) follow the resource lookup pattern:
///   1. Explicit parameter value (highest priority)
///   2. Resource lookup via scope path (`$scope.$fieldName.$suffix`)
///   3. `null` / absent (lowest priority)
///
/// This allows resources to provide default values while code can override
/// any specific field at construction time.
class TomTextFormFieldBase<T> extends TomField<T> {
  /// Returns translated text with scope prefix applied.
  String t(String key) => TomCtr.text(scope, key);
  
  /// Returns translated text or `null` if no resource exists.
  String? tOrNull(String key) => TomCtr.textOrNull(scope, key);

  late TextEditingController _textEditingController;
  String currentRawValue = "";
  final ValueNotifier<String?> _errorText = ValueNotifier(null);
  String? _inputError;

  final List<String? Function(String)> _valueValidators = [];
  final List<String? Function(String)> _inputValidators = [];

  late String Function(T) _valueToTextConverter;
  late T Function(String) _valueConverter;

  // Individual InputDecoration parameters — override resource lookup.
  final String? labelText;
  final String? helperText;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool? enabled;

  TomTextFormFieldBase(
    super.fieldName,
    super.initialValue, {
    super.form,
    super.obscureText,
    this.labelText,
    this.helperText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled,
    T Function(String)? valueConverter,
    String Function(T)? valueToTextConverter,
    String? Function(String)? inputValidator,
    String? Function(String)? valueValidator,
  }) {
    // Set default converters
    _valueToTextConverter = valueToTextConverter ?? _defaultToTextConverter;
    _valueConverter = valueConverter ?? _defaultFromTextConverter;

    _textEditingController = TextEditingController(
      text: _valueToTextConverter(initialValue),
    );

    if (inputValidator != null) {
      _inputValidators.add(inputValidator);
    }

    // Check for pattern validator in resources
    final pattern = tOrNull('$fieldName.pattern');
    if (pattern != null) {
      _inputValidators.add((String value) {
        if (RegExp(pattern).hasMatch(value)) {
          return null;
        } else {
          return t("$fieldName.errors.pattern");
        }
      });
    }

    if (valueValidator != null) {
      _valueValidators.add(valueValidator);
    }

    _textEditingController.addListener(_onTextChanged);
  }

  String _defaultToTextConverter(T value) => value.toString();

  T _defaultFromTextConverter(String value) {
    if (T == String) {
      return value as T;
    } else {
      throw UnimplementedError('Override _valueConverter for type $T');
    }
  }

  void _onTextChanged() {
    var value = _textEditingController.value.text;
    bool valid = true;
    String? error;
    for (var inputValidator in _inputValidators) {
      error = inputValidator(value);
      if (error != null && _errorText.value == null) {
        _errorText.value = t(error);
      }
      if (error != null) {
        valid = false;
      }
    }
    if (valid) {
      currentRawValue = value;
      _errorText.value = null;
    } else {
      _textEditingController.text = currentRawValue;
      _textEditingController.selection = TextSelection.collapsed(
        offset: currentRawValue.length,
      );
      if (_inputError != null) {
        _errorText.value = _inputError;
        _inputError = null;
      }
    }
  }

  @override
  bool validate() {
    bool valid = true;
    for (var valueValidator in _valueValidators) {
      String? error = valueValidator(_textEditingController.value.text);
      if (error != null && _errorText.value == null) {
        _errorText.value = t(error);
      }
      if (error != null) {
        valid = false;
      }
    }
    if (valid) {
      _errorText.value = null;
    }
    return valid;
  }

  @override
  T save() {
    return super.set(_valueConverter(_textEditingController.value.text));
  }

  @override
  String? get errorText => _errorText.value;

  // ---------------------------------------------------------------------------
  // Resource resolution helpers
  // ---------------------------------------------------------------------------

  /// Resolves an icon from resources, returning an [Icon] widget or `null`.
  Widget? _resolveIconOrNull(String key) {
    final bp = scope.isEmpty ? fieldName : '$scope.$fieldName';
    final iconData = TomCtr.icon(bp, key);
    if (iconData != null) return Icon(iconData);
    return null;
  }

  @override
  Widget getField() {
    // Parameter → resource → null
    final resolvedLabel = labelText ?? TomCtr.textOrNull(scope, '$fieldName.label') ?? fieldName;
    final resolvedHelper = helperText ?? TomCtr.textOrNull(scope, '$fieldName.helperText');
    final resolvedHint = hintText ?? TomCtr.textOrNull(scope, '$fieldName.hintText');
    final resolvedPrefixIcon = prefixIcon ?? _resolveIconOrNull('prefixIcon');
    final resolvedSuffixIcon = suffixIcon ?? _resolveIconOrNull('suffixIcon');

    return ValueListenableBuilder(
      builder: (context, value, widget) {
        return TextField(
          decoration: InputDecoration(
            labelText: resolvedLabel,
            helperText: resolvedHelper,
            hintText: resolvedHint,
            errorText: _errorText.value,
            prefixIcon: resolvedPrefixIcon,
            suffixIcon: resolvedSuffixIcon,
            enabled: enabled ?? true,
          ),
          controller: _textEditingController,
          obscureText: obscureText,
          enabled: enabled ?? true,
        );
      },
      valueListenable: _errorText,
    );
  }

  void reset() {
    set(initialValue);
    String textValue = _valueToTextConverter(initialValue);
    _textEditingController.value = TextEditingValue(
      text: textValue,
      selection: TextSelection.fromPosition(
        TextPosition(offset: textValue.length),
      ),
    );
  }

  @override
  T set(T value) {
    String textValue = _valueToTextConverter(value);
    _textEditingController.value = TextEditingValue(
      text: textValue,
      selection: TextSelection.fromPosition(
        TextPosition(offset: textValue.length),
      ),
    );
    return super.set(value);
  }
}

/// Standard string form field for text input.
class TomStringFormField extends TomTextFormFieldBase<String> {
  TomStringFormField(
    super.fieldName,
    super.initialValue, {
    super.form,
    super.obscureText,
    super.labelText,
    super.helperText,
    super.hintText,
    super.prefixIcon,
    super.suffixIcon,
    super.enabled,
    super.inputValidator,
    super.valueValidator,
  });
}

/// Password form field with obscured text.
class TomPasswordFormField extends TomTextFormFieldBase<String> {
  TomPasswordFormField(
    super.fieldName,
    super.initialValue, {
    super.form,
    super.labelText,
    super.helperText,
    super.hintText,
    super.prefixIcon,
    super.suffixIcon,
    super.enabled,
    super.inputValidator,
    super.valueValidator,
  }) : super(obscureText: true);
}

/// Email form field with built-in email validation.
class TomEmailFormField extends TomTextFormFieldBase<String> {
  TomEmailFormField(
    super.fieldName,
    super.initialValue, {
    super.form,
    super.obscureText,
    super.labelText,
    super.helperText,
    super.hintText,
    super.prefixIcon,
    super.suffixIcon,
    super.enabled,
    super.inputValidator,
  }) {
    _valueValidators.add((value) {
      if (value.isEmpty) {
        return "$fieldName.errors.required";
      }
      if (!isValidEmail(value)) {
        return "$fieldName.errors.validEmail";
      }
      return null;
    });
  }

  static bool isValidEmail(String s) {
    return RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)+$",
    ).hasMatch(s);
  }
}

/// Integer form field with int conversion and optional min/max validation.
class TomIntFormField extends TomTextFormFieldBase<int> {
  final int? min;
  final int? max;

  TomIntFormField(
    super.fieldName,
    super.initialValue, {
    super.form,
    this.min,
    this.max,
    super.labelText,
    super.helperText,
    super.hintText,
    super.prefixIcon,
    super.suffixIcon,
    super.enabled,
    super.inputValidator,
    super.valueValidator,
  }) : super(
          valueConverter: (s) => int.tryParse(s) ?? 0,
          valueToTextConverter: (v) => v.toString(),
        ) {
    // Add input validator to only allow digits and optional leading minus
    _inputValidators.add((value) {
      if (value.isEmpty) return null;
      if (int.tryParse(value) == null) {
        return "$fieldName.errors.invalidNumber";
      }
      return null;
    });

    // Add min/max validation
    if (min != null || max != null) {
      _valueValidators.add((value) {
        final intVal = int.tryParse(value);
        if (intVal == null) return null; // handled by input validator
        if (min != null && intVal < min!) {
          return "$fieldName.errors.min";
        }
        if (max != null && intVal > max!) {
          return "$fieldName.errors.max";
        }
        return null;
      });
    }
  }
}

/// Double/decimal form field with double conversion and optional min/max validation.
class TomDoubleFormField extends TomTextFormFieldBase<double> {
  final double? min;
  final double? max;

  TomDoubleFormField(
    super.fieldName,
    super.initialValue, {
    super.form,
    this.min,
    this.max,
    super.labelText,
    super.helperText,
    super.hintText,
    super.prefixIcon,
    super.suffixIcon,
    super.enabled,
    super.inputValidator,
    super.valueValidator,
  }) : super(
          valueConverter: (s) => double.tryParse(s) ?? 0.0,
          valueToTextConverter: (v) => v.toString(),
        ) {
    // Add input validator to only allow valid decimal numbers
    _inputValidators.add((value) {
      if (value.isEmpty) return null;
      if (double.tryParse(value) == null) {
        return "$fieldName.errors.invalidNumber";
      }
      return null;
    });

    // Add min/max validation
    if (min != null || max != null) {
      _valueValidators.add((value) {
        final doubleVal = double.tryParse(value);
        if (doubleVal == null) return null; // handled by input validator
        if (min != null && doubleVal < min!) {
          return "$fieldName.errors.min";
        }
        if (max != null && doubleVal > max!) {
          return "$fieldName.errors.max";
        }
        return null;
      });
    }
  }
}

/// Test form demonstrating the form field system.
@tomReflector
class TestForm extends TomForm {
  TestForm() : super(formId: "test_form");

  late final TomEmailFormField email;
  late final TomPasswordFormField password;
  late final TomStringFormField username;
  late final TomIntFormField age;
  late final TomDoubleFormField rating;

  @override
  void createFormElements() {
    email = TomEmailFormField('email', '', form: this);
    password = TomPasswordFormField('password', '', form: this);
    username = TomStringFormField('username', '', form: this);
    age = TomIntFormField('age', 0, form: this, min: 0, max: 150);
    rating = TomDoubleFormField('rating', 0.0, form: this, min: 0.0, max: 5.0);
    
  }
}