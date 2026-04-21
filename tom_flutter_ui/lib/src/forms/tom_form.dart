import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../actions/tom_action.dart';
import '../actions/tom_action_controller.dart';
import '../widget_base/tom_construction_helpers.dart';
import '../widget_base/tom_screen_elements_provider.dart';
import 'events/tom_form_event.dart';
import 'events/tom_form_event_listener.dart';
import 'events/tom_form_event_source.dart';
import 'fields/tom_field_widget_adapter.dart';
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

  /// The currently bound data object, or `null` when [unbind] has been
  /// called or [bind] never ran. Read-only — mutate via [bind] / [unbind].
  T? get currentBinding => _binding;

  /// The bound data object's initial snapshot (values at bind/save time).
  Map<String, dynamic>? _initialSnapshot;

  /// Event listeners.
  final List<TomFormEventListener> _listeners = [];

  /// Fires on every form event — use to rebuild UI that depends on
  /// aggregate state such as [isValid] or [fieldsWithErrors], which react
  /// to validation transitions that are NOT carried on the TomObservable
  /// value channel.
  final _FormChangeNotifier _changes = _FormChangeNotifier();
  Listenable get changes => _changes;

  // --- TomActionController interface ---

  final List<TomAction> _actions = [];

  @override
  TomAuthorizationGroup? authorizationGroup;

  @override
  String get controllerId => formId;

  @override
  String get canonicalPrefix => formId;

  @override
  TomAuthState get authState => TomAuthorization.resolveAuth(basePath);

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
    scope = TomScope.current;
    final parentPath = scope.getScopePath();
    basePath = parentPath.isNotEmpty ? '$parentPath.$formId' : formId;
    TomScope.withScope(formId, () => createFormElements());
  }

  /// Subclasses create their fields here (called inside form's scope).
  void createFormElements();

  // --- Binding (§5) ---

  /// Nested forms discovered via TomClass reflection. Populated on first
  /// access so bind / isDirty / isValid / save / discard / validate can
  /// fan out without every caller having to enumerate children by hand.
  Iterable<TomForm> get nestedForms =>
      getMembers().values.whereType<TomForm>();

  /// Bind to a TomClass instance.
  ///
  /// `target.getValues()` carries the whole state subtree (including
  /// every nested TomClass), and TomClass.setValues recurses through
  /// that subtree writing values into matching member observables. On
  /// top of that this method walks every nested [TomForm] (via
  /// [nestedForms]) and runs the binding lifecycle — initial snapshot,
  /// per-field `_initialValue` reset, pristine validation state, and
  /// `FieldBoundEvent` / `FormBoundEvent` dispatch — all the way down.
  void bind(T target) {
    _binding = target;
    setValues(target.getValues());
    _applyBindLifecycle(target);
  }

  /// Core of [bind]: per-form lifecycle reset + recursion into nested
  /// forms. Assumes values have already been written (via [setValues] on
  /// the root form), so the recursion itself never sets values — it only
  /// commits each level's "current values are the new initial".
  void _applyBindLifecycle(TomClass target) {
    _initialSnapshot = Map<String, dynamic>.unmodifiable(target.getValues());
    for (final field in fields.values) {
      field._initialValue = field.get();
      field._debounceTimer?.cancel();
      field._validationNotifier.value = const ValidationPristine();
      _fireEvent(FieldBoundEvent(source: field.tomId));
      if (field.autoValidate) {
        field.validate();
      }
    }
    final targetMembers = target.getMembers();
    for (final entry in getMembers().entries) {
      final nested = entry.value;
      if (nested is TomForm) {
        final nestedTarget = targetMembers[entry.key];
        if (nestedTarget is TomClass) {
          nested._binding = nestedTarget;
          nested._applyBindLifecycle(nestedTarget);
        }
      }
    }
    onBound();
    _fireEvent(FormBoundEvent(source: formId));
  }

  /// Save form values back to bound state.
  ///
  /// Runs full validation (including nested forms' validations) first —
  /// returns `false` if any errors. On success, commits every field in
  /// the form tree and fires `FormSavedEvent` at each level.
  Future<bool> save() async {
    final errors = await validate();
    if (errors.isNotEmpty) return false;
    _applySave();
    return true;
  }

  void _applySave() {
    onSaving();
    _binding?.setValues(getValues());
    for (final field in fields.values) {
      field.commit();
    }
    _initialSnapshot = Map<String, dynamic>.unmodifiable(getValues());
    for (final nested in nestedForms) {
      nested._applySave();
    }
    onSaved();
    _fireEvent(FormSavedEvent(source: formId));
  }

  /// Discard edits — resets every field in this form and every nested
  /// form back to its last bound / committed value.
  void discard() {
    onDiscarding();
    for (final field in fields.values) {
      field.reset();
    }
    for (final nested in nestedForms) {
      nested.discard();
    }
    onDiscarded();
    _fireEvent(FormDiscardedEvent(source: formId));
  }

  /// Detach from the bound state object.
  ///
  /// Resets all fields (including nested form fields) to pristine,
  /// clears the binding reference and the initial snapshot at every
  /// level. Call this when the form tree is no longer editing a data
  /// object.
  void unbind() {
    onUnbinding();
    for (final field in fields.values) {
      field.reset();
    }
    for (final nested in nestedForms) {
      nested.unbind();
    }
    _binding = null;
    _initialSnapshot = null;
  }

  // --- State queries ---

  /// Whether any field — in this form OR any nested form — has a value
  /// that differs from its initial (bound / last-committed) value.
  bool get isDirty =>
      fields.values.any((f) => f.isDirty) ||
      nestedForms.any((f) => f.isDirty);

  /// Whether every field in the form tree currently has a successful
  /// validation state. Pristine fields count as NOT valid.
  bool get isValid =>
      fields.values.every((f) => f.validationState is ValidationSuccess) &&
      nestedForms.every((f) => f.isValid);

  // --- Validation (async — §20) ---

  /// Validate every field in this form AND every nested form, then run
  /// this form's cross-field validation. Returns the combined error
  /// list.
  Future<List<FormValidationError>> validate() async {
    final errors = <FormValidationError>[];

    // 1. Validate this form's own fields in parallel.
    final fieldResults = await Future.wait(
      fields.values.map((f) => f.validate()),
    );
    for (var i = 0; i < fields.values.length; i++) {
      final result = fieldResults.elementAt(i);
      if (result is ValidationError) {
        final field = fields.values.elementAt(i);
        errors.add(FormValidationError(
          errorKey: result.errorKey,
          params: result.params,
          fields: [field],
        ));
      }
    }

    // 2. Recurse into nested forms (they fire their own FormValidatedEvent).
    for (final nested in nestedForms) {
      errors.addAll(await nested.validate());
    }

    // 3. Cross-field validation — only when every field below has passed.
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
  TomField? getField(String tomId) => fields[tomId];

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
    _changes.fire();
  }

  // --- Dispose ---

  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    _listeners.clear();
    _changes.dispose();
  }
}

/// Tiny [ChangeNotifier] subclass so `notifyListeners` stays encapsulated
/// (avoids `invalid_use_of_protected_member` at the call site).
class _FormChangeNotifier extends ChangeNotifier {
  void fire() => notifyListeners();
}

// ---------------------------------------------------------------------------
// TomField<T> — Base Form Field (§4)
// ---------------------------------------------------------------------------

abstract class TomField<T> extends TomObject<T> implements TomAuthorizable {
  TomField(
    this.tomId,
    this._initialValue, {
    this.form,
    this.obscureText = false,
    this.validators = const [],
    this.autoValidate = false,
    this.tomGroup,
    this.authorizer,
    this.uiStateController,
    this.actionIcon,
    this.actionIconTooltip,
    this.onActionIconPressed,
  }) : super(_initialValue) {
    // When the field knows its form, derive scope from the form's
    // basePath — so a field can be instantiated at its declaration site
    // (e.g. `late final x = TomFormStringInput('x', '', form: this)`)
    // and still end up with a basePath that includes the form's formId,
    // regardless of whatever TomScope.current happens to carry when the
    // late initializer fires (typically during reflection-driven member
    // enumeration, where only the outer scope is pushed).
    scope = form != null
        ? form!.basePath
        : TomScope.current.getScopePath();
    basePath = scope.isNotEmpty ? '$scope.$tomId' : tomId;
    tomGroup?.register(this);
  }

  late String scope;
  late final String basePath;

  /// The short identifier this field was constructed with. Matches the
  /// `<suffix>` consumed by resource lookups of the form
  /// `"$basePath.<suffix>"`. For the full path use [basePath].
  @override
  String tomId;

  TomForm? form;
  bool obscureText;

  /// Optional icon rendered in the field's action slot (trailing by
  /// default, configurable per-style via `actionIconPlacement`). When
  /// set, the anatomy paints this icon as a tap target — wire the tap
  /// via [onActionIconPressed]. The slot is shared with the slow-
  /// validation spinner: while async validation is in flight the
  /// spinner takes precedence so the user always sees progress before
  /// seeing the (still valid) action trigger.
  ///
  /// Pass an [IconData]-backed widget (e.g. `const Icon(Icons.search)`)
  /// or a full [IconButton] if the action needs ripple / tooltip
  /// semantics that the icon alone wouldn't render.
  final Widget? actionIcon;

  /// Optional tooltip used when [actionIcon] is a plain icon and the
  /// anatomy needs to wrap it with an [IconButton] / [Tooltip].
  final String? actionIconTooltip;

  /// Callback invoked when the action icon is tapped. The anatomy
  /// renders a tap target only when this is non-null — so fields that
  /// supply a decorative icon without an onPressed stay un-tappable.
  final VoidCallback? onActionIconPressed;

  // --- Value tracking ---

  T _initialValue;

  /// The value when the field was initialized or last committed.
  T get initialValue => _initialValue;

  /// Whether the field value differs from initial.
  bool get isDirty => get() != _initialValue;

  /// Set a new value from user interaction.
  ///
  /// Fires [FieldValueChangedEvent], transitions out of pristine state,
  /// and schedules debounced re-validation. Fast validators run after
  /// [validationDebounce]; slow validators run after [slowValidationDebounce].
  void setValue(T newValue) {
    final oldValue = get();
    if (newValue == oldValue) return;
    set(newValue);
    form?._fireEvent(FieldValueChangedEvent(
      source: tomId,
      oldValue: oldValue,
      newValue: newValue,
    ));
    // Transition out of pristine — clear to success for UX responsiveness.
    _slowValidationPending = false;
    _validationNotifier.value = const ValidationSuccess();
    // Debounced re-validation
    _debounceTimer?.cancel();
    _slowDebounceTimer?.cancel();
    _debounceTimer = Timer(validationDebounce, () => _validateFast());
    if (hasSlowValidators) {
      _slowDebounceTimer = Timer(slowValidationDebounce, () => _validateSlow());
    }
  }

  /// Run only fast validators (called after fast debounce).
  Future<void> _validateFast() async {
    for (final validator in validators) {
      if (validator is SlowValidator) continue;
      final result = await (validator as Validator<T>)(get());
      if (result is ValidationError) {
        _slowValidationPending = false;
        _slowDebounceTimer?.cancel();
        _validationNotifier.value = result;
        form?._fireEvent(FieldValidatedEvent(
          source: tomId,
          result: result,
        ));
        return;
      }
    }
    // Fast validators passed — keep current state (slow may still be pending)
    if (!_slowValidationPending) {
      // No slow validators or they haven't started yet — mark success for now
      if (!hasSlowValidators) {
        _validationNotifier.value = const ValidationSuccess();
        form?._fireEvent(FieldValidatedEvent(
          source: tomId,
          result: _validationNotifier.value,
        ));
      }
    }
  }

  /// Run only slow validators (called after slow debounce).
  Future<void> _validateSlow() async {
    // First re-check fast validators (value may have changed)
    for (final validator in validators) {
      if (validator is SlowValidator) continue;
      final result = await (validator as Validator<T>)(get());
      if (result is ValidationError) {
        _slowValidationPending = false;
        _validationNotifier.value = result;
        form?._fireEvent(FieldValidatedEvent(
          source: tomId,
          result: result,
        ));
        return;
      }
    }

    // Run slow validators with pending state
    _slowValidationPending = true;
    _validationNotifier.value = const ValidationPending();
    final slowValidators = validators.whereType<SlowValidator<T>>().toList();
    for (final slow in slowValidators) {
      final result = await slow.validate(get());
      if (result is ValidationError) {
        _slowValidationPending = false;
        _validationNotifier.value = result;
        form?._fireEvent(FieldValidatedEvent(
          source: tomId,
          result: result,
        ));
        return;
      }
    }
    _slowValidationPending = false;
    _validationNotifier.value = const ValidationSuccess();
    form?._fireEvent(FieldValidatedEvent(
      source: tomId,
      result: _validationNotifier.value,
    ));
  }

  /// Commit current value as the new initial value.
  /// Resets validation state to [ValidationPristine] — no errors shown after save.
  void commit() {
    _initialValue = get();
    _debounceTimer?.cancel();
    _slowDebounceTimer?.cancel();
    _slowValidationPending = false;
    _validationNotifier.value = const ValidationPristine();
    form?._fireEvent(FieldCommittedEvent(source: tomId));
  }

  /// Reset to initial value and reset validation to pristine.
  void reset() {
    set(_initialValue);
    _debounceTimer?.cancel();
    _slowDebounceTimer?.cancel();
    _slowValidationPending = false;
    _validationNotifier.value = const ValidationPristine();
  }

  // --- Authorization ---

  @override
  TomAuthorizationGroup? tomGroup;

  /// Per-field authorizer (optional).
  TomAuthorizer? authorizer;

  /// Build-time UI state controller (optional).
  TomUIStateController? uiStateController;

  /// Resolved effective authorization state (see §19 for resolution order).
  @override
  TomAuthState get effectiveAuthState => resolveEffectiveAuth();

  /// Resolve the effective authorization state for this field.
  ///
  /// CRITICAL: All four layers must be evaluated. Skipping any layer
  /// (especially group auth) is a severe bug.
  ///
  /// Resolution order (§19):
  /// 1. Resource-based authorization via basePath
  /// 2. Group authorization (applies group's auth via narrowing)
  /// 3. Form authorization (implicit group — always narrows)
  /// 4. Per-widget authorizer
  /// 5. Build-time UI state controller
  TomAuthState resolveEffectiveAuth() {
    // 1. Resource-based auth
    var state = TomAuthorization.resolveAuth(basePath);

    // 2. Group auth (CRITICAL — must not be skipped)
    if (tomGroup != null) {
      state = tomGroup!.applyMode(state);
    }

    // 3. Form auth (narrows)
    if (form != null) {
      final formPath = form!.scopePath.isNotEmpty
          ? '${form!.scopePath}.${form!.formId}'
          : form!.formId;
      state = state.narrow(TomAuthorization.resolveAuth(formPath));
    }

    // 4. Per-widget authorizer
    if (authorizer != null) {
      state = authorizer!.effectiveAuth(state);
    }

    // 5. UI state controller
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

  /// Validators applied to this field.
  ///
  /// Accepts both [Validator<T>] (fast) and [SlowValidator<T>] (slow).
  /// Fast validators run without showing a pending spinner.
  /// Slow validators (e.g., remote API calls) show a spinner and trigger
  /// after a longer debounce.
  final List<Object> validators;

  /// Whether this field validates immediately on bind without waiting
  /// for user interaction. Useful for auto-save forms.
  final bool autoValidate;

  /// Current validation state — starts as [ValidationPristine].
  /// Backed by a [ValueNotifier] so UI rebuilds are driven independently
  /// from value-change observers. Validation transitions must NOT call
  /// [notifyObservers] — that channel is for value changes only.
  final ValueNotifier<ValidationResult> _validationNotifier =
      ValueNotifier(const ValidationPristine());

  /// Listenable fired when the validation state changes. UI code (field
  /// widgets, `TomFormInspector`, …) should subscribe here rather than
  /// observing the field as a value.
  ValueListenable<ValidationResult> get validationListenable =>
      _validationNotifier;

  ValidationResult get validationState => _validationNotifier.value;

  /// Whether slow validation is currently in progress.
  /// Used by decoration mixin to decide whether to show a spinner.
  bool _slowValidationPending = false;

  bool get isSlowValidationPending => _slowValidationPending;

  /// Debounce timer for fast validation.
  Timer? _debounceTimer;

  /// Debounce timer for slow validation (separate, longer).
  Timer? _slowDebounceTimer;

  /// Debounce duration for fast validation. Default: 300ms.
  Duration get validationDebounce => const Duration(milliseconds: 300);

  /// Debounce duration for slow validation. Default: 600ms.
  Duration get slowValidationDebounce => const Duration(milliseconds: 600);

  /// Whether this field has any slow validators.
  bool get hasSlowValidators => validators.any((v) => v is SlowValidator);

  /// Validate the current value.
  ///
  /// Runs fast validators first (no pending spinner), then slow validators
  /// (with pending spinner). Stops on first error at any stage.
  Future<ValidationResult> validate() async {
    // Run fast validators first — no pending state
    for (final validator in validators) {
      if (validator is SlowValidator) continue;
      final result = await (validator as Validator<T>)(get());
      if (result is ValidationError) {
        _slowValidationPending = false;
        _validationNotifier.value = result;
        form?._fireEvent(FieldValidatedEvent(
          source: tomId,
          result: result,
        ));
        return result;
      }
    }

    // Run slow validators — show pending state
    final slowValidators = validators.whereType<SlowValidator<T>>().toList();
    if (slowValidators.isNotEmpty) {
      _slowValidationPending = true;
      _validationNotifier.value = const ValidationPending();
      for (final slow in slowValidators) {
        final result = await slow.validate(get());
        if (result is ValidationError) {
          _slowValidationPending = false;
          _validationNotifier.value = result;
          form?._fireEvent(FieldValidatedEvent(
            source: tomId,
            result: result,
          ));
          return result;
        }
      }
      _slowValidationPending = false;
    }

    const success = ValidationSuccess();
    _validationNotifier.value = success;
    form?._fireEvent(FieldValidatedEvent(
      source: tomId,
      result: success,
    ));
    return success;
  }

  // --- Widget ---

  /// The implementation widget for this field (overridden by concrete classes).
  Widget get widget;

  // --- Lifecycle ---

  /// Dispose resources (timers, controllers, listeners).
  void dispose() {
    _debounceTimer?.cancel();
    _slowDebounceTimer?.cancel();
    _validationNotifier.dispose();
  }

  @override
  String toString() => '$runtimeType($tomId: ${get()}, dirty: $isDirty)';
}

/// Base class for text-based form fields with TextEditingController support.
///
/// Individual [InputDecoration] parameters (e.g. [labelText], [helperText],
/// [prefixIcon]) follow the resource lookup pattern:
///   1. Explicit parameter value (highest priority)
///   2. Resource lookup via scope path (`$scope.$tomId.$suffix`)
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
    super.tomId,
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
    final pattern = tOrNull('$tomId.pattern');
    if (pattern != null) {
      _inputValidators.add((String value) {
        if (RegExp(pattern).hasMatch(value)) {
          return null;
        } else {
          return t("$tomId.errors.pattern");
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
    final bp = scope.isEmpty ? tomId : '$scope.$tomId';
    final iconData = TomCtr.icon(bp, key);
    if (iconData != null) return Icon(iconData);
    return null;
  }

  @override
  Widget get widget {
    // Parameter → resource → null
    final resolvedLabel = labelText ?? TomCtr.textOrNull(scope, '$tomId.label') ?? tomId;
    final resolvedHelper = helperText ?? TomCtr.textOrNull(scope, '$tomId.helperText');
    final resolvedHint = hintText ?? TomCtr.textOrNull(scope, '$tomId.hintText');
    final resolvedPrefixIcon = prefixIcon ?? _resolveIconOrNull('prefixIcon');
    final resolvedSuffixIcon = suffixIcon ?? _resolveIconOrNull('suffixIcon');

    // Classic fields render a ValueListenableBuilder; wrap it in a
    // TomFieldWidgetAdapter so AclContainer's TomAuthorizable-aware
    // hide-unauthorized pass can still reach this field's auth state.
    return TomFieldWidgetAdapter(
      field: this,
      child: ValueListenableBuilder(
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
      ),
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
class TomFormStringInputClassic extends TomTextFormFieldBase<String> {
  TomFormStringInputClassic(
    super.tomId,
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
class TomFormPasswordStringInputClassic extends TomTextFormFieldBase<String> {
  TomFormPasswordStringInputClassic(
    super.tomId,
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
class TomFormEmailStringInputClassic extends TomTextFormFieldBase<String> {
  TomFormEmailStringInputClassic(
    super.tomId,
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
        return "$tomId.errors.required";
      }
      if (!isValidEmail(value)) {
        return "$tomId.errors.validEmail";
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
class TomFormIntInputClassic extends TomTextFormFieldBase<int> {
  final int? min;
  final int? max;

  TomFormIntInputClassic(
    super.tomId,
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
        return "$tomId.errors.invalidNumber";
      }
      return null;
    });

    // Add min/max validation
    if (min != null || max != null) {
      _valueValidators.add((value) {
        final intVal = int.tryParse(value);
        if (intVal == null) return null; // handled by input validator
        if (min != null && intVal < min!) {
          return "$tomId.errors.min";
        }
        if (max != null && intVal > max!) {
          return "$tomId.errors.max";
        }
        return null;
      });
    }
  }
}

/// **Legacy** double/decimal form field with double conversion and optional min/max validation.
@Deprecated('Use typed form fields from Phase 2+ instead')
class TomFormDoubleInputClassic extends TomTextFormFieldBase<double> {
  final double? min;
  final double? max;

  TomFormDoubleInputClassic(
    super.tomId,
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
        return "$tomId.errors.invalidNumber";
      }
      return null;
    });

    // Add min/max validation
    if (min != null || max != null) {
      _valueValidators.add((value) {
        final doubleVal = double.tryParse(value);
        if (doubleVal == null) return null; // handled by input validator
        if (min != null && doubleVal < min!) {
          return "$tomId.errors.min";
        }
        if (max != null && doubleVal > max!) {
          return "$tomId.errors.max";
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
  late final TomFormEmailStringInputClassic email;
  // ignore: deprecated_member_use_from_same_package
  late final TomFormPasswordStringInputClassic password;
  // ignore: deprecated_member_use_from_same_package
  late final TomFormStringInputClassic username;
  // ignore: deprecated_member_use_from_same_package
  late final TomFormIntInputClassic age;
  // ignore: deprecated_member_use_from_same_package
  late final TomFormDoubleInputClassic rating;

  @override
  void createFormElements() {
    // ignore: deprecated_member_use_from_same_package
    email = TomFormEmailStringInputClassic('email', '', form: this);
    // ignore: deprecated_member_use_from_same_package
    password = TomFormPasswordStringInputClassic('password', '', form: this);
    // ignore: deprecated_member_use_from_same_package
    username = TomFormStringInputClassic('username', '', form: this);
    // ignore: deprecated_member_use_from_same_package
    age = TomFormIntInputClassic('age', 0, form: this, min: 0, max: 150);
    // ignore: deprecated_member_use_from_same_package
    rating = TomFormDoubleInputClassic('rating', 0.0, form: this, min: 0.0, max: 5.0);
  }
}