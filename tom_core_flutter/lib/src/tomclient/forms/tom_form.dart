import 'package:flutter/material.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'tom_fields.dart';

/// An observable collection of [TomFieldOld]s keyed by field name.
///
/// `TomFormOld` is the legacy form aggregate of `tom_core_flutter`. It extends
/// the kernel [TomMap] (field-name → field), so the whole form is observable,
/// and offers form-wide [validate], [save], and [errors] operations plus widget
/// builders for the contained fields.
///
/// > Superseded by the `TomForm` framework in `tom_flutter_ui`; retained for
/// > existing consumers (e.g. `tom_uam_client`).
class TomFormOld extends TomMap<String, TomFieldOld> {
  TomFormOld(super.form) : super.ofMap();

  /// Builds the widget for every field, in iteration order.
  List<Widget> getFields() {
    return values.map((field) => field.getField()).toList();
  }

  /// Builds the widget for the field registered under [name].
  Widget getField(String name) {
    return this[name]!.getField();
  }

  /// Validates every field and returns `true` only when all pass. Runs every
  /// field's validator (no short-circuit), so all error messages are populated.
  bool validate() {
    bool valid = true;
    for (var element in values) {
      valid = element.validate() && valid;
    }
    return valid;
  }

  /// Returns the current error message of each field, keyed by field name
  /// (`null` for fields with no error).
  Map<String, String?> errors() {
    Map<String, String?> result = {};
    for (var element in values) {
      result[element.fieldName] = element.errorText;
    }
    return result;
  }

  /// Saves every field and returns the converted values keyed by field name.
  ///
  /// Notifications are muted across the batch so observers see a single
  /// consistent state rather than one event per field.
  Map<String, Object> save() {
    Map<String, Object> result = {};
    mute();
    for (var element in values) {
      result[element.fieldName] = element.save();
    }
    unmute();
    return result;
  }
}
