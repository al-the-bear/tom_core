import 'package:flutter/material.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// An observable single form field backing a Material [TextField].
///
/// `TomFieldOld` is the legacy form-field primitive of `tom_core_flutter`. It
/// extends the kernel [TomObject] (so it can be observed and bound like any
/// other Tom value) and wires a [TextEditingController] to two validation
/// passes:
///
/// - **input validators** run on every keystroke (via the controller listener)
///   and *reject* the change — the text reverts to [currentRawValue] when an
///   input validator fails;
/// - **value validators** run on demand from [validate] and surface an error
///   without reverting the text.
///
/// Field labels, helper text, the optional input pattern, and error messages
/// are resolved from the kernel [TomTextResourceProvider] under the key prefix
/// `"$formName.$fieldName"` (e.g. `form.email.label`,
/// `form.email.errors.pattern`). Missing keys fall back to the key itself, so
/// an unconfigured field still renders.
///
/// > A richer form framework lives in `tom_flutter_ui` (`TomForm`/`TomField`).
/// > This `Old` type is retained for existing consumers (e.g.
/// > `tom_uam_client`).
class TomFieldOld<T> extends TomObject<T> {
  /// Resolves a localized string by key (returns the key when missing).
  String Function(String) get t =>
      TomTextResourceProvider.getAppResources().getText;

  /// Resolves a localized string by key, or `null` when the key is missing.
  String? Function(String) get tOrNull =>
      TomTextResourceProvider.getAppResources().getTextOrNull;

  /// Field identifier within the form; second segment of every resource key.
  String fieldName;

  /// Owning form identifier; first segment of every resource key.
  String formName;

  /// Value the field is constructed with and reverts to on [reset].
  T initialValue;

  /// Whether the rendered [TextField] obscures its text (e.g. passwords).
  bool obscureText;

  TomFieldOld(
    this.formName,
    this.fieldName,
    this.initialValue, {
    this.obscureText = false,
    T Function(String)? valueConverter,
    String Function(T)? valueToTextConverter,
    String? Function(String)? inputValidator,
    String? Function(String)? valueValidator,
  }) : super(initialValue) {
    if (valueToTextConverter != null) {
      _valueToTextConverter = valueToTextConverter;
    }
    _textEditingController = TextEditingController(
      text: _valueToTextConverter(initialValue),
    );
    if (inputValidator != null) {
      _inputValidators.add(inputValidator);
    }
    String patternKey = "$formName.$fieldName.pattern";
    final pattern = tOrNull(patternKey);
    if (pattern != null) {
      _inputValidators.add((String value) {
        if (RegExp(pattern).hasMatch(value)) {
          return null;
        } else {
          return t("$formName.$fieldName.errors.pattern");
        }
      });
    }
    if (valueValidator != null) {
      _valueValidators.add(valueValidator);
    }
    if (valueConverter != null) {
      _valueConverter = valueConverter;
    }
    _textEditingController.addListener(() {
      // The revert below re-assigns the controller text, which synchronously
      // re-fires this listener. Without this guard the re-entrant (now-valid)
      // pass cleared the error we just set, so input errors never surfaced
      // (bug §57). Suppressing the re-entry keeps the error visible.
      if (_suppressInputListener) return;
      final value = _textEditingController.value.text;
      final error = _firstInputError(value);
      if (error == null) {
        currentRawValue = value;
        _errorText.value = null;
      } else {
        _errorText.value = t(error);
        _setControllerText(currentRawValue);
      }
    });
  }

  /// Runs the input validators against [value] and returns the first failing
  /// (resolved) message, or `null` when every validator passes.
  String? _firstInputError(String value) {
    for (var inputValidator in _inputValidators) {
      final error = inputValidator(value);
      if (error != null) {
        return error;
      }
    }
    return null;
  }

  /// Whether the controller-change listener should ignore the next change.
  ///
  /// Set while this class programmatically rewrites the controller text (a
  /// revert, a [set], or a [reset]) so those internal writes do not re-trigger
  /// input validation.
  bool _suppressInputListener = false;

  /// Replaces the editor text without re-triggering the input-validation
  /// listener, placing the cursor at the end.
  void _setControllerText(String text) {
    _suppressInputListener = true;
    _textEditingController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _suppressInputListener = false;
  }

  /// Runs every value validator against the current text.
  ///
  /// Sets [errorText] to the first failing validator's (localized) message and
  /// returns `false`; clears the error and returns `true` when all pass.
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

  /// Converts the current text to `T`, stores it as the field value, and
  /// returns it. Notifies observers of the field.
  T save() {
    return super.set(_valueConverter(_textEditingController.value.text));
  }

  /// The current error message, or `null` when the field is valid.
  String? get errorText => _errorText.value;

  late TextEditingController _textEditingController;

  /// Builds the Material [TextField] for this field, rebuilding whenever the
  /// error state changes.
  Widget getField() {
    final String labelText = t("$formName.$fieldName.label");
    final String helperText = t("$formName.$fieldName.helperText");
    return ValueListenableBuilder(
      builder: (context, value, widget) {
        return TextField(
          decoration: InputDecoration(
            label: Text(labelText),
            helperText: helperText,
            errorText: _errorText.value,
          ),
          controller: _textEditingController,
          obscureText: obscureText,
        );
      },
      valueListenable: _errorText,
    );
  }

  String currentRawValue = "";
  final ValueNotifier<String?> _errorText = ValueNotifier(null);

  final List<String? Function(String)> _valueValidators = [];
  final List<String? Function(String)> _inputValidators = [];

  String Function(T) _valueToTextConverter = (T value) {
    return value.toString();
  };

  T Function(String) _valueConverter = (String value) {
    if (T == String) {
      return value as T;
    } else {
      throw Exception();
    }
  };

  /// Restores the field to [initialValue] and syncs the text editor to match.
  ///
  /// Restoration is unconditional — it bypasses input validation (an absent or
  /// otherwise input-invalid initial value is still restored) and clears any
  /// surfaced error.
  void reset() {
    final textValue = _valueToTextConverter(initialValue);
    super.set(initialValue);
    _setControllerText(textValue);
    currentRawValue = textValue;
    _errorText.value = null;
  }

  /// Sets the field value and mirrors it into the text editor (cursor placed
  /// at the end).
  ///
  /// An input-invalid value is rejected the same way a keystroke is: the error
  /// is surfaced and neither the stored value nor the editor text changes, so
  /// the two never diverge (bug §58). A valid value updates both in lock-step.
  @override
  T set(T value) {
    final textValue = _valueToTextConverter(value);
    final error = _firstInputError(textValue);
    if (error != null) {
      _errorText.value = t(error);
      return get();
    }
    _setControllerText(textValue);
    currentRawValue = textValue;
    _errorText.value = null;
    return super.set(value);
  }
}

/// A [TomFieldOld] that requires a non-empty, syntactically valid email.
///
/// Adds a value validator yielding the resource keys
/// `"$formName.$fieldName.errors.required"` (empty) and `".errors.validEmail"`
/// (malformed).
class TomEmailField<T> extends TomFieldOld<T> {
  TomEmailField(
    super.formName,
    super.fieldName,
    super.initialValue, {
    super.obscureText,
  }) {
    _valueValidators.add((value) {
      if (value.isEmpty) {
        return "$formName.$fieldName.errors.required";
      }
      if (!isValidEmail(value)) {
        return "$formName.$fieldName.errors.validEmail";
      }
      return null;
    });
  }

  /// Returns `true` when [s] is a syntactically valid email address.
  static bool isValidEmail(String s) {
    return RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)+$",
    )
    //r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$")
    //r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$')
    .hasMatch(s);
  }
}

/// A [TomFieldOld] that requires a non-empty password of at least 4 characters.
///
/// Adds a value validator yielding the resource keys
/// `"$formName.$fieldName.errors.required"` (empty) and
/// `".errors.minimumLength"` (shorter than 4). Obscures its text by default.
class TomPasswordField<T> extends TomFieldOld<T> {
  TomPasswordField(
    super.formName,
    super.fieldName,
    super.initialValue, {
    super.obscureText = true,
  }) {
    _valueValidators.add((value) {
      if (value.isEmpty) {
        return "$formName.$fieldName.errors.required";
      }
      if (value.length < 4) {
        return "$formName.$fieldName.errors.minimumLength";
      }
      return null;
    });
  }
}
