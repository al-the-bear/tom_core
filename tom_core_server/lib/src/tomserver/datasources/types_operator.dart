import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'sql_dialects.dart';

abstract class TomDbType<T> extends TomObject<T> {
  TomDbType(super.value);

  @override
  String toString() {
    return "TomDbType $runtimeType ${get()}";
  }
}

class TomDbInt extends TomDbType<int?> {
  TomDbInt(super.value);
  static TomDbInt of(String? s) {
    return s == null ? TomDbInt(null) : TomDbInt(int.parse(s));
  }
}

class TomDbDouble extends TomDbType<double?> {
  TomDbDouble(super.value);
  static TomDbDouble of(String? s) {
    return s == null ? TomDbDouble(null) : TomDbDouble(double.parse(s));
  }
}

class TomDbString extends TomDbType<String?> {
  TomDbString(super.value);
  static TomDbString of(String? s) {
    return TomDbString(s);
  }
}

class TomDbDateTime extends TomDbType<DateTime?> {
  TomDbDateTime(super.value);
  static TomDbDateTime of(String? s) {
    return s == null ? TomDbDateTime(null) : TomDbDateTime(DateTime.parse(s));
  }
}

class TomDbDate extends TomDbType<TomZonedDate?> {
  TomDbDate(super.value);
  static TomDbDate of(String? s) {
    return s == null ? TomDbDate(null) : TomDbDate(TomZonedDate.parseFromString(s));
  }
}

class TomDbTime extends TomDbType<TomZonedTime?> {
  TomDbTime(super.value);
  static TomDbTime of(String? s) {
    return s == null ? TomDbTime(null) : TomDbTime(TomZonedTime.parseFromString(s));
  }
}

class TomDbBool extends TomDbType<bool?> {
  TomDbBool(super.value);
  static TomDbBool of(String? s) {
    return s == null ? TomDbBool(null) : TomDbBool(bool.parse(s));
  }
}

abstract class TomOperator<R> {
  static TomStandardSqlDialect defaultDialect = TomStandardSqlDialect();
  SqlString generate(TomStandardSqlDialect t);

  late Type returnType;

  List<String> getParameters(TomStandardSqlDialect t) => [];

  Set<String> getFields(TomStandardSqlDialect t);

  TomOperator() {
    returnType = R;
  }

  @override
  String toString() => analyze(0);

  String indent(int i) {
    String indent = "\n";
    for (int j = 0; j < i; j++) {
      indent += "\t";
    }
    return indent;
  }

  String analyze(int l) => "TomOperator $runtimeType $returnType";
}
