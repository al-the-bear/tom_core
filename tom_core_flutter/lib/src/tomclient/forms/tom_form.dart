import 'package:flutter/material.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'tom_fields.dart';

class TomForm extends TomMap<String, TomField> {
  TomForm(super.form) : super.ofMap();

  List<Widget> getFields() {
    return values.map((field) => field.getField()).toList();
  }

  Widget getField(String name) {
    return this[name]!.getField();
  }

  bool validate() {
    bool valid = true;
    for (var element in values) {
      valid = element.validate() && valid;
    }
    return valid;
  }

  Map<String, String?> errors() {
    Map<String, String?> result = {};
    for (var element in values) {
      result[element.fieldName] = element.errorText;
    }
    return result;
  }

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
