import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../widget_base/tom_construction_helpers.dart';
import '../widget_base/tom_screen_elements_provider.dart';
import 'events/tom_form_event.dart';
import 'events/tom_form_event_listener.dart';
import 'validation/form_validation_error.dart';
import 'validation/validation_result.dart';

// ---------------------------------------------------------------------------
// TomForm — Form Container (§5)
// ---------------------------------------------------------------------------

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

  /// The bound data object's initial snapshot (values at bind/save time).
  Map<String, dynamic>? _initialSnapshot;

  /// Event listeners.
  final List<TomFormEventListener> _listeners = [];

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

  /// Subclasses create their fields here (called inside form's scope).
  void createFormElements();

  // --- Widget accessors (backward compatible) ---

  List<Widget> getFieldWidgets() {
    return fields.values.map((field) => field.getField()).toList();
  }

  Widget getFieldWidget(String name) {
    return fields[name]!.getField();
  }

  // --- Binding (§5) ---

  /// Bind to a TomClass instance.
  void bind(TomClass target) {
    final values = target.getValues();
    _initialSnapshot = Map<String, dynamic>.unmodifiable(values);
    setValues(values);
    for (final field in fields.values) {
      field.commit();
    }
    onBound();
    _fireEvent(FormBoundEvent(source: formId));
  }

  /// Save form values back to bound state.
  /// Returns `false` if the form is not valid.
  bool saveForm() {
    if (!isValid) return false;
    onSaving();
    final values = getFormValues();
    _initialSnapshot = Map<String, dynamic>.unmodifiable(values);
    for (final field in fields.values) {
      field.commit();
    }
    onSaved();
    _fireEvent(FormSavedEvent(source: formId));
    return true;
  }

  /// Discard edits, reset all fields.
  void discard() {
    onDiscarding();
    for (final field in fields.values) {
      field.reset();
    }
    onDiscarded();
    _fireEvent(FormDiscardedEvent(source: formId));
  }

  // --- State queries ---

  /// Whether any field's value differs from its initial value.
  bool get isDirty => fields.values.any((f) => f.isDirty);

  /// Whether all fields currently have a successful validation state.
  bool get isValid => fields.values.every(
    (f) => f.validationState is ValidationSuccess,
  );

  // --- Validation (async — §20) ---

  /// Validate all fields in parallel, then run cross-field validation.
  Future<List<FormValidationError>> validateAllFields() async {
    // 1. Validate all fields in parallel
    final fieldResults = await Future.wait(
      fields.values.map((f) => f.validateField()),
    );

    // 2. Collect field-level errors
    final errors = <FormValidationError>[];
    for (var i = 0; i < fields.values.length; i++) {
      final result = fieldResults.elementAt(i);
      if (result is ValidationError) {
        final field = fields.values.elementAt(i);
        errors.add(FormValidationError(
          errorKey: result.errorKey,
          params: result.params,
          fields: [field.fieldName],
        ));
      }
    }

    // 3. Run cross-field validation only if all fields passed
    if (errors.isEmpty) {
      errors.addAll(await validateForm());
    }

    return errors;
  }

  /// Override for cross-field validation. Always async.
  Future<List<FormValidationError>> validateForm() async => [];

  // --- Inspection ---

  /// Get a field by its name.
  TomField? getFieldByName(String fieldName) => fields[fieldName];

  /// Get the current values of all fields.
  Map<String, dynamic> getFormValues() {
    final result = <String, dynamic>{};
    for (final entry in fields.entries) {
      result[entry.key] = entry.value.get();
    }
    return result;
  }

  /// Get the initial snapshot (values at bind time / last save).
  Map<String, dynamic>? get initialSnapshot => _initialSnapshot;

  /// All fields that currently have validation errors.
  List<TomField> get fieldsWithErrors => fields.values
      .where((f) => f.validationState is ValidationError)
      .toList();

  /// All fields whose values differ from initial.
  List<TomField> get dirtyFields => fields.values
      .where((f) => f.isDirty)
      .toList();

  /// A map of field names to error texts for all fields with errors.
  Map<String, String?> errors() {
    final result = <String, String?>{};
    for (var element in fields.values) {
      result[element.fieldName] = element.errorText;
    }
    return result;
  }

  // --- Lifecycle hooks ---

  @protected
  void onBound() {}

  @protected
  void onSaving() {}

  @protected
  void onSaved() {}

  @protected
  void onDiscarding() {}

  @protected
  void onDiscarded() {}

  // --- Event system ---

  void addListener(TomFormEventListener listener) {
    _listeners.add(listener);
  }

  void removeListener(TomFormEventListener listener) {
    _listeners.remove(listener);
  }

  /// Dispatch an event to all registered listeners.
  void fireEvent(TomFormEvent event) => _fireEvent(event);

  void _fireEvent(TomFormEvent event) {
    for (final listener in _listeners) {
      listener.handleEvent(event);
    }
  }

  // --- Dispose ---

  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    _listeners.clear();
  }
}

// ---------------------------------------------------------------------------
// TomField<T> — Base Form Field (§4)
// ---------------------------------------------------------------------------

abstract class TomField<T> extends TomObject<T> implements TomAuthorizable {
  TomField(
    this.fieldName,
    this._initialValue, {
    this.form,
    this.obscureText = false,
    this.fieldValidators = const [],
    this.tomGroup,
    this.authorizer,
    this.uiStateController,
  }) : super(_initialValue) {
    scope = TomScope.current.getScopePath();
    basePath = scope.isNotEmpty ? '$scope.$fieldName' : fieldName;
  }

  late String scope;
  late final String basePath;
  String fieldName;
  TomForm? form;
  bool obscureText;

  // --- Value tracking ---

  T _initialValue;

  /// The value when the field was initialized or last committed.
  T get initialValue => _initialValue;

  /// Whether the field value differs from initial.
  bool get isDirty => get() != _initialValue;

  /// Commit current value as the new initial value.
  void commit() {
    _initialValue = get();
    form?._fireEvent(FieldCommittedEvent(source: fieldName));
  }

  /// Reset to initial value and clear validation state.
  void reset() {
    set(_initialValue);
    _debounceTimer?.cancel();
    _validationState = const ValidationSuccess();
  }

  // --- Authorization ---

  @override
  TomAuthorizationGroup? tomGroup;

  /// Per-field authorizer (optional).
  TomAuthorizer? authorizer;

  /// Build-time UI state controller (optional).
  TomUIStateController? uiStateController;

  @override
  String? get tomId => basePath;

  /// Resolve the effective authorization state for this field.
  ///
  /// Resolution order (§19):
  /// 1. Resource-based authorization via basePath
  /// 2. Form authorization (implicit group — always narrows)
  /// 3. Per-widget authorizer
  /// 4. Build-time UI state controller
  TomAuthState resolveEffectiveAuth() {
    // 1. Resource-based auth
    var state = TomAuthorization.resolveAuth(basePath);

    // 2. Form auth (narrows)
    if (form != null) {
      final formPath = form!.scopePath.isNotEmpty
          ? '${form!.scopePath}.${form!.formId}'
          : form!.formId;
      state = state.narrow(TomAuthorization.resolveAuth(formPath));
    }

    // 3. Per-widget authorizer
    if (authorizer != null) {
      state = authorizer!.effectiveAuth(state);
    }

    // 4. UI state controller
    if (uiStateController != null) {
      state = uiStateController!.apply(state);
    }

    return state;
  }

  /// Whether the field is currently editable (full auth).
  bool get isEditable => resolveEffectiveAuth() == TomAuthState.full;

  /// Whether the field is visible (not `none`).
  bool get isVisible => resolveEffectiveAuth() != TomAuthState.none;

  // --- Validation ---

  /// Validators applied to this field (new validation system).
  final List<Validator<T>> fieldValidators;

  /// Current validation state — may be pending, success, or error.
  ValidationResult _validationState = const ValidationSuccess();

  ValidationResult get validationState => _validationState;

  /// Debounce timer for change-triggered validation.
  Timer? _debounceTimer;

  /// Debounce duration for change-triggered validation. Default: 300ms.
  Duration get validationDebounce => const Duration(milliseconds: 300);

  /// Validate the current value using the new validation system.
  /// Runs all [fieldValidators] sequentially, stopping on first error.
  Future<ValidationResult> validateField() async {
    _validationState = const ValidationPending();

    for (final validator in fieldValidators) {
      final result = await validator(get());
      if (result is ValidationError) {
        _validationState = result;
        form?._fireEvent(FieldValidatedEvent(
          source: fieldName,
          result: _validationState,
        ));
        return result;
      }
    }

    _validationState = const ValidationSuccess();
    form?._fireEvent(FieldValidatedEvent(
      source: fieldName,
      result: _validationState,
    ));
    return _validationState;
  }

  // --- Legacy validation (for backward compatibility with existing fields) ---

  /// Legacy validate method. Override in concrete fields.
  bool validate() => true;

  /// Legacy save method. Override in concrete fields.
  T save() => get();

  /// Legacy error text. Override in concrete fields.
  String? get errorText => null;

  // --- Widget ---

  /// Returns the widget for this field. Override in concrete subclasses.
  Widget getField();

  // --- Lifecycle ---

  /// Dispose resources (timers, controllers, listeners).
  void dispose() {
    _debounceTimer?.cancel();
  }

  @override
  String toString() => '$runtimeType($fieldName: ${get()}, dirty: $isDirty)';
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

  @override
  void reset() {
    super.reset();
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