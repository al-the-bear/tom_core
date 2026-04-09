import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../actions/tom_action.dart';
import '../actions/tom_action_controller.dart';
import '../widget_base/tom_construction_helpers.dart';
import '../widget_base/tom_screen_elements_provider.dart';
import 'events/tom_form_event.dart';
import 'events/tom_form_event_listener.dart';
import 'events/tom_form_event_source.dart';
import 'validation/form_validation_error.dart';
import 'validation/validation_result.dart';

// ---------------------------------------------------------------------------
// TomForm — Form Container (§5)
// ---------------------------------------------------------------------------

@tomReflector
abstract class TomForm<T extends TomClass> extends TomClass
    implements
        TomScreenElementsProvider,
        TomActionController,
        TomFormEventSource {
  /// The scope for this form's resource/authorization lookups.
  @override
  late final TomScope scope;

  /// The scope path as a string (convenience getter).
  String get scopePath => scope.getScopePath();

  /// The scope-qualified base path for this form.
  late final String basePath;

  late final String formId;
  late final TomForm? parentForm;
  late final Map<String, TomField> fields = {};

  /// The bound data object (back-reference for save push-back).
  T? _binding;

  /// The bound data object's initial snapshot (values at bind/save time).
  Map<String, dynamic>? _initialSnapshot;

  /// Event listeners.
  final List<TomFormEventListener> _listeners = [];

  // --- TomActionController interface ---

  final List<TomAction> _actions = [];

  @override
  TomAuthorizationGroup? authorizationGroup;

  @override
  String get controllerId => formId;

  @override
  String get canonicalPrefix => formId;

  @override
  TomAuthState get authState => TomAuthorization.resolveAuth(canonicalPrefix);

  @override
  void registerAction(TomAction action) {
    _actions.add(action);
  }

  @override
  List<TomAction> get actions => List.unmodifiable(_actions);

  @override
  TomAction? findAction(String actionId) {
    for (final action in _actions) {
      if (action.actionId == actionId) return action;
    }
    return null;
  }

  TomForm({required this.formId, this.parentForm}) {
    scope = TomScope.current;
    final parentPath = scope.getScopePath();
    basePath = parentPath.isNotEmpty ? '$parentPath.$formId' : formId;
    getMembers().entries.where((entry) => entry.value is TomField).forEach((
      entry,
    ) {
      final field = entry.value as TomField;
      field.form = this;
      fields[entry.key] = field;
    });
  }

  @override
  void prepareForSelfObservation() {
    TomScope.withScope(formId, () => createFormElements());
  }

  /// Subclasses create their fields here (called inside form's scope).
  void createFormElements();

  // --- Binding (§5) ---

  /// Bind to a TomClass instance.
  void bind(T target) {
    _binding = target;
    final values = target.getValues();
    _initialSnapshot = Map<String, dynamic>.unmodifiable(values);
    setValues(values);
    for (final field in fields.values) {
      field.commit();
      _fireEvent(FieldBoundEvent(source: field.fieldId));
    }
    onBound();
    _fireEvent(FormBoundEvent(source: formId));
  }

  /// Save form values back to bound state.
  /// Returns `false` if the form is not valid.
  bool save() {
    if (!isValid) return false;
    onSaving();
    _binding?.setValues(getValues());
    for (final field in fields.values) {
      field.commit();
    }
    _initialSnapshot = Map<String, dynamic>.unmodifiable(getValues());
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
  Future<List<FormValidationError>> validate() async {
    // 1. Validate all fields in parallel
    final fieldResults = await Future.wait(
      fields.values.map((f) => f.validate()),
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
          fields: [field.fieldId],
        ));
      }
    }

    // 3. Run cross-field validation only if all fields passed
    if (errors.isEmpty) {
      errors.addAll(await validateForm());
    }

    _fireEvent(FormValidatedEvent(source: formId, errors: errors));
    return errors;
  }

  /// Override for cross-field validation. Always async.
  Future<List<FormValidationError>> validateForm() async => [];

  // --- Inspection ---

  /// Get a field by its ID.
  TomField? getField(String fieldId) => fields[fieldId];

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

  // --- Lifecycle hooks ---

  @protected
  void onBound() {}

  @protected
  void onUnbinding() {}

  @protected
  void onSaving() {}

  @protected
  void onSaved() {}

  @protected
  void onDiscarding() {}

  @protected
  void onDiscarded() {}

  // --- Event system ---

  @override
  void addListener(TomFormEventListener listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(TomFormEventListener listener) {
    _listeners.remove(listener);
  }

  /// Dispatch an event to all registered listeners.
  @override
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
    this.fieldId,
    this._initialValue, {
    this.form,
    this.obscureText = false,
    this.validators = const [],
    this.tomGroup,
    this.authorizer,
    this.uiStateController,
  }) : super(_initialValue) {
    scope = TomScope.current.getScopePath();
    basePath = scope.isNotEmpty ? '$scope.$fieldId' : fieldId;
  }

  late String scope;
  late final String basePath;
  String fieldId;
  TomForm? form;
  bool obscureText;

  // --- Value tracking ---

  T _initialValue;

  /// The value when the field was initialized or last committed.
  T get initialValue => _initialValue;

  /// Whether the field value differs from initial.
  bool get isDirty => get() != _initialValue;

  /// Set a new value from user interaction.
  ///
  /// Fires [FieldValueChangedEvent], clears any validation error immediately,
  /// and schedules debounced re-validation.
  void setValue(T newValue) {
    final oldValue = get();
    if (newValue == oldValue) return;
    set(newValue);
    form?._fireEvent(FieldValueChangedEvent(
      source: fieldId,
      oldValue: oldValue,
      newValue: newValue,
    ));
    // Clear error immediately for UX responsiveness
    _validationState = const ValidationSuccess();
    // Debounced re-validation
    _debounceTimer?.cancel();
    _debounceTimer = Timer(validationDebounce, () => validate());
  }

  /// Commit current value as the new initial value.
  void commit() {
    _initialValue = get();
    form?._fireEvent(FieldCommittedEvent(source: fieldId));
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

  /// Resolved effective authorization state (see §19 for resolution order).
  TomAuthState get effectiveAuthState => resolveEffectiveAuth();

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
  bool get isEditable => effectiveAuthState == TomAuthState.full;

  /// Whether the field is visible (not `none`).
  bool get isVisible => effectiveAuthState != TomAuthState.none;

  // --- Validation ---

  /// Validators applied to this field (new validation system).
  final List<Validator<T>> validators;

  /// Current validation state — may be pending, success, or error.
  ValidationResult _validationState = const ValidationSuccess();

  ValidationResult get validationState => _validationState;

  /// Debounce timer for change-triggered validation.
  Timer? _debounceTimer;

  /// Debounce duration for change-triggered validation. Default: 300ms.
  Duration get validationDebounce => const Duration(milliseconds: 300);

  /// Validate the current value.
  /// Runs all [validators] sequentially, stopping on first error.
  Future<ValidationResult> validate() async {
    _validationState = const ValidationPending();

    for (final validator in validators) {
      final result = await validator(get());
      if (result is ValidationError) {
        _validationState = result;
        form?._fireEvent(FieldValidatedEvent(
          source: fieldId,
          result: _validationState,
        ));
        return result;
      }
    }

    _validationState = const ValidationSuccess();
    form?._fireEvent(FieldValidatedEvent(
      source: fieldId,
      result: _validationState,
    ));
    return _validationState;
  }

  // --- Widget ---

  /// The implementation widget for this field (overridden by concrete classes).
  Widget get widget;

  // --- Lifecycle ---

  /// Dispose resources (timers, controllers, listeners).
  void dispose() {
    _debounceTimer?.cancel();
  }

  @override
  String toString() => '$runtimeType($fieldId: ${get()}, dirty: $isDirty)';
}

/// Base class for text-based form fields with TextEditingController support.
///
/// Individual [InputDecoration] parameters (e.g. [labelText], [helperText],
/// [prefixIcon]) follow the resource lookup pattern:
///   1. Explicit parameter value (highest priority)
///   2. Resource lookup via scope path (`$scope.$fieldId.$suffix`)
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
    super.fieldId,
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
    final pattern = tOrNull('$fieldId.pattern');
    if (pattern != null) {
      _inputValidators.add((String value) {
        if (RegExp(pattern).hasMatch(value)) {
          return null;
        } else {
          return t("$fieldId.errors.pattern");
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
      // Sync text to TomObject value (bypass override to avoid controller loop)
      super.set(_valueConverter(value));
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

  String? get errorText => _errorText.value;

  // ---------------------------------------------------------------------------
  // Resource resolution helpers
  // ---------------------------------------------------------------------------

  /// Resolves an icon from resources, returning an [Icon] widget or `null`.
  Widget? _resolveIconOrNull(String key) {
    final bp = scope.isEmpty ? fieldId : '$scope.$fieldId';
    final iconData = TomCtr.icon(bp, key);
    if (iconData != null) return Icon(iconData);
    return null;
  }

  @override
  Widget get widget {
    // Parameter → resource → null
    final resolvedLabel = labelText ?? TomCtr.textOrNull(scope, '$fieldId.label') ?? fieldId;
    final resolvedHelper = helperText ?? TomCtr.textOrNull(scope, '$fieldId.helperText');
    final resolvedHint = hintText ?? TomCtr.textOrNull(scope, '$fieldId.hintText');
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

/// **Legacy** standard string form field for text input.
///
/// Prefer [TomFormStringInput] from Phase 1 for new code.
@Deprecated('Use TomFormStringInput instead')
class TomStringFormFieldClassic extends TomTextFormFieldBase<String> {
  TomStringFormFieldClassic(
    super.fieldId,
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

/// **Legacy** password form field with obscured text.
///
/// Prefer [TomFormStringInput] with `obscureText: true` for new code.
@Deprecated('Use TomFormStringInput with obscureText: true instead')
class TomPasswordFormFieldClassic extends TomTextFormFieldBase<String> {
  TomPasswordFormFieldClassic(
    super.fieldId,
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

/// **Legacy** email form field with built-in email validation.
///
/// Prefer [TomFormStringInput] with email validators for new code.
@Deprecated('Use TomFormStringInput with email validators instead')
class TomEmailFormFieldClassic extends TomTextFormFieldBase<String> {
  TomEmailFormFieldClassic(
    super.fieldId,
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
        return "$fieldId.errors.required";
      }
      if (!isValidEmail(value)) {
        return "$fieldId.errors.validEmail";
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

/// **Legacy** integer form field with int conversion and optional min/max validation.
@Deprecated('Use typed form fields from Phase 2+ instead')
class TomIntFormFieldClassic extends TomTextFormFieldBase<int> {
  final int? min;
  final int? max;

  TomIntFormFieldClassic(
    super.fieldId,
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
        return "$fieldId.errors.invalidNumber";
      }
      return null;
    });

    // Add min/max validation
    if (min != null || max != null) {
      _valueValidators.add((value) {
        final intVal = int.tryParse(value);
        if (intVal == null) return null; // handled by input validator
        if (min != null && intVal < min!) {
          return "$fieldId.errors.min";
        }
        if (max != null && intVal > max!) {
          return "$fieldId.errors.max";
        }
        return null;
      });
    }
  }
}

/// **Legacy** double/decimal form field with double conversion and optional min/max validation.
@Deprecated('Use typed form fields from Phase 2+ instead')
class TomDoubleFormFieldClassic extends TomTextFormFieldBase<double> {
  final double? min;
  final double? max;

  TomDoubleFormFieldClassic(
    super.fieldId,
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
        return "$fieldId.errors.invalidNumber";
      }
      return null;
    });

    // Add min/max validation
    if (min != null || max != null) {
      _valueValidators.add((value) {
        final doubleVal = double.tryParse(value);
        if (doubleVal == null) return null; // handled by input validator
        if (min != null && doubleVal < min!) {
          return "$fieldId.errors.min";
        }
        if (max != null && doubleVal > max!) {
          return "$fieldId.errors.max";
        }
        return null;
      });
    }
  }
}

/// Legacy test form demonstrating the classic form field system.
@tomReflector
class TestFormClassic extends TomForm<TomClass> {
  TestFormClassic() : super(formId: "test_form");

  // ignore: deprecated_member_use_from_same_package
  late final TomEmailFormFieldClassic email;
  // ignore: deprecated_member_use_from_same_package
  late final TomPasswordFormFieldClassic password;
  // ignore: deprecated_member_use_from_same_package
  late final TomStringFormFieldClassic username;
  // ignore: deprecated_member_use_from_same_package
  late final TomIntFormFieldClassic age;
  // ignore: deprecated_member_use_from_same_package
  late final TomDoubleFormFieldClassic rating;

  @override
  void createFormElements() {
    // ignore: deprecated_member_use_from_same_package
    email = TomEmailFormFieldClassic('email', '', form: this);
    // ignore: deprecated_member_use_from_same_package
    password = TomPasswordFormFieldClassic('password', '', form: this);
    // ignore: deprecated_member_use_from_same_package
    username = TomStringFormFieldClassic('username', '', form: this);
    // ignore: deprecated_member_use_from_same_package
    age = TomIntFormFieldClassic('age', 0, form: this, min: 0, max: 150);
    // ignore: deprecated_member_use_from_same_package
    rating = TomDoubleFormFieldClassic('rating', 0.0, form: this, min: 0.0, max: 5.0);
  }
}