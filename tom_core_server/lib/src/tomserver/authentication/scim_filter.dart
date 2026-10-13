/// SCIM attribute paths and the filter language (RFC 7644, section 3.4.2.2).
///
/// One grammar serves both uses: a `filter` query parameter is an expression,
/// and a PATCH `path` is an attribute path that may carry a value filter —
/// `emails[type eq "work"].value`.
///
/// What is supported:
///
/// | Part | Supported |
/// | ---- | --------- |
/// | Operators | `eq` `ne` `co` `sw` `ew` `gt` `ge` `lt` `le` `pr` |
/// | Logic | `and`, `or`, `not ( … )`, parentheses — `and` binds tighter |
/// | Paths | `attr`, `attr.sub`, a schema-URN prefix, `attr[filter]` |
/// | Values | strings, numbers, `true`, `false`, `null` |
///
/// Attribute names are case-insensitive. String comparison is too, except for
/// the attributes SCIM defines as case-exact — `id`, `externalId` and the
/// `value` of a member or group reference.
library;

import 'dart:convert';

import 'scim_resource.dart';

/// An attribute path: an optional schema URN, an attribute, an optional value
/// filter and an optional sub-attribute.
class TomScimPath {
  /// Creates a path.
  const TomScimPath(
    this.attribute, {
    this.schema,
    this.filter,
    this.subAttribute,
  });

  /// The schema URN the path was qualified with, or `null`.
  final String? schema;

  /// The attribute, as written.
  final String attribute;

  /// The value filter in brackets, or `null`.
  final TomScimFilter? filter;

  /// The sub-attribute after the attribute (or after the filter), or `null`.
  final String? subAttribute;

  /// Parses [text] for a resource of [type]. Throws `scim.invalid_path`.
  static TomScimPath parse(String text, TomScimResourceType type) {
    final parser = _Parser(text.trim(), type, path: true);
    final path = parser._path();
    if (!parser._atEnd) {
      throw _syntaxError(text, path: true, 'unexpected "${parser._rest}"');
    }
    return path;
  }

  /// Whether this path names an attribute inside an extension schema.
  bool get inExtension => schema != null;

  @override
  String toString() =>
      '${schema == null ? '' : '$schema:'}$attribute'
      '${filter == null ? '' : '[…]'}'
      '${subAttribute == null ? '' : '.$subAttribute'}';
}

/// A filter expression, evaluated against a resource's JSON representation.
sealed class TomScimFilter {
  const TomScimFilter();

  /// Parses [text] for a resource of [type]. Throws `scim.invalid_filter`.
  static TomScimFilter parse(String text, TomScimResourceType type) {
    final parser = _Parser(text.trim(), type, path: false);
    final filter = parser._or();
    if (!parser._atEnd) {
      throw _syntaxError(text, path: false, 'unexpected "${parser._rest}"');
    }
    return filter;
  }

  /// Whether [json] — a resource, or one element of a multi-valued attribute
  /// inside a value filter — matches.
  bool matches(Map<String, Object?> json);
}

/// `a and b`.
class TomScimAnd extends TomScimFilter {
  /// Creates the conjunction.
  const TomScimAnd(this.left, this.right);

  /// The left operand.
  final TomScimFilter left;

  /// The right operand.
  final TomScimFilter right;

  @override
  bool matches(Map<String, Object?> json) =>
      left.matches(json) && right.matches(json);
}

/// `a or b`.
class TomScimOr extends TomScimFilter {
  /// Creates the disjunction.
  const TomScimOr(this.left, this.right);

  /// The left operand.
  final TomScimFilter left;

  /// The right operand.
  final TomScimFilter right;

  @override
  bool matches(Map<String, Object?> json) =>
      left.matches(json) || right.matches(json);
}

/// `not (a)`.
class TomScimNot extends TomScimFilter {
  /// Creates the negation.
  const TomScimNot(this.operand);

  /// The negated expression.
  final TomScimFilter operand;

  @override
  bool matches(Map<String, Object?> json) => !operand.matches(json);
}

/// `attr[filter]` — some element of the multi-valued `attr` matches.
class TomScimValuePath extends TomScimFilter {
  /// Creates the value filter.
  const TomScimValuePath(this.attribute, this.filter);

  /// The multi-valued attribute.
  final String attribute;

  /// What an element must match.
  final TomScimFilter filter;

  @override
  bool matches(Map<String, Object?> json) => [
    for (final element in scimValues(json, attribute))
      if (element is Map) element,
  ].any((element) => filter.matches(element.cast<String, Object?>()));
}

/// `attr op value`, or `attr pr`.
class TomScimComparison extends TomScimFilter {
  /// Creates the comparison.
  const TomScimComparison(
    this.attribute,
    this.operator,
    this.value, {
    this.caseExact = false,
  });

  /// The attribute, dotted when it names a sub-attribute.
  final String attribute;

  /// The operator, lower case.
  final String operator;

  /// The literal compared with; `null` for `pr`, or the literal `null`.
  final Object? value;

  /// Whether strings compare case-sensitively.
  final bool caseExact;

  @override
  bool matches(Map<String, Object?> json) {
    final values = scimValues(json, attribute);
    if (operator == 'pr') {
      return values.any(
        (v) =>
            v != null &&
            !(v is String && v.isEmpty) &&
            !(v is List && v.isEmpty) &&
            !(v is Map && v.isEmpty),
      );
    }
    if (operator == 'ne') {
      return !values.any((v) => _compare(v, 'eq'));
    }
    return values.any((v) => _compare(v, operator));
  }

  bool _compare(Object? actual, String op) {
    final expected = value;
    if (expected == null || actual == null) {
      return op == 'eq' && expected == actual;
    }
    if (expected is bool || actual is bool) {
      return op == 'eq' && '$actual'.toLowerCase() == '$expected'.toLowerCase();
    }
    if (expected is num && actual is num) {
      final c = actual.compareTo(expected);
      return _ordered(op, c);
    }
    var a = '$actual';
    var e = '$expected';
    if (!caseExact) {
      a = a.toLowerCase();
      e = e.toLowerCase();
    }
    return switch (op) {
      'eq' => a == e,
      'co' => a.contains(e),
      'sw' => a.startsWith(e),
      'ew' => a.endsWith(e),
      _ => _ordered(op, a.compareTo(e)),
    };
  }

  static bool _ordered(String op, int c) => switch (op) {
    'eq' => c == 0,
    'gt' => c > 0,
    'ge' => c >= 0,
    'lt' => c < 0,
    'le' => c <= 0,
    _ => false,
  };
}

/// The values at [path] — `attr` or `attr.sub`, optionally prefixed with an
/// extension schema URN and a colon — in [json], flattening multi-valued
/// attributes, with attribute names compared case-insensitively.
List<Object?> scimValues(Map<String, Object?> json, String path) {
  if (path.toLowerCase().startsWith('urn:')) {
    final split = path.lastIndexOf(':');
    final extension = scimLookup(json, path.substring(0, split));
    return extension is Map
        ? scimValues(
            extension.cast<String, Object?>(),
            path.substring(split + 1),
          )
        : const [];
  }
  var current = <Object?>[json];
  for (final segment in path.split('.')) {
    final next = <Object?>[];
    for (final node in current) {
      if (node is! Map) continue;
      final value = scimLookup(node.cast<String, Object?>(), segment);
      if (value is List) {
        next.addAll(value);
      } else if (value != null) {
        next.add(value);
      }
    }
    current = next;
  }
  return current;
}

/// The value of [name] in [json], matched case-insensitively.
Object? scimLookup(Map<String, Object?> json, String name) {
  final key = scimKeyOf(json, name);
  return key == null ? null : json[key];
}

/// The key of [json] that equals [name] case-insensitively, or `null`.
String? scimKeyOf(Map<String, Object?> json, String name) {
  final wanted = name.toLowerCase();
  for (final key in json.keys) {
    if (key.toLowerCase() == wanted) return key;
  }
  return null;
}

/// Attributes whose string values compare case-sensitively.
const Set<String> _caseExact = {
  'id',
  'externalid',
  'members.value',
  'groups.value',
  'value',
};

/// The refusal of [text] as a path (`scim.invalid_path`) or a filter
/// (`scim.invalid_filter`), saying [what] could not be read.
TomScimException _syntaxError(String text, String what, {required bool path}) =>
    TomScimException(
      path ? 'scim.invalid_path' : 'scim.invalid_filter',
      'The ${path ? 'path' : 'filter'} "$text" cannot be read: $what.',
      status: 400,
      scimType: path ? 'invalidPath' : 'invalidFilter',
    );

class _Parser {
  _Parser(this.text, this.type, {required this.path});

  final String text;
  final TomScimResourceType type;
  final bool path;
  int _at = 0;

  bool get _atEnd {
    _skip();
    return _at >= text.length;
  }

  String get _rest => text.substring(_at);

  TomScimException _error(String what) => _syntaxError(text, path: path, what);

  void _skip() {
    while (_at < text.length && text.codeUnitAt(_at) <= 32) {
      _at++;
    }
  }

  bool _peekChar(String c) {
    _skip();
    return _at < text.length && text[_at] == c;
  }

  void _expectChar(String c) {
    if (!_peekChar(c)) throw _error('expected "$c"');
    _at++;
  }

  /// The next bare word — an attribute path, an operator or a keyword.
  String _word() {
    _skip();
    final start = _at;
    while (_at < text.length) {
      final c = text[_at];
      if (c.codeUnitAt(0) <= 32 || '()[]"'.contains(c)) break;
      _at++;
    }
    if (_at == start) throw _error('expected an attribute or operator');
    return text.substring(start, _at);
  }

  /// Whether the next word is [keyword] (case-insensitively); consumes it.
  bool _keyword(String keyword) {
    _skip();
    final saved = _at;
    if (_at >= text.length || '()[]"'.contains(text[_at])) return false;
    final word = _word();
    if (word.toLowerCase() == keyword) return true;
    _at = saved;
    return false;
  }

  TomScimFilter _or() {
    var left = _and();
    while (_keyword('or')) {
      left = TomScimOr(left, _and());
    }
    return left;
  }

  TomScimFilter _and() {
    var left = _unary();
    while (_keyword('and')) {
      left = TomScimAnd(left, _unary());
    }
    return left;
  }

  TomScimFilter _unary() {
    if (_keyword('not')) {
      _expectChar('(');
      final inner = _or();
      _expectChar(')');
      return TomScimNot(inner);
    }
    if (_peekChar('(')) {
      _at++;
      final inner = _or();
      _expectChar(')');
      return inner;
    }
    final attribute = _attributeName(_word());
    if (_peekChar('[')) {
      _at++;
      final inner = _or();
      _expectChar(']');
      return TomScimValuePath(attribute, inner);
    }
    final op = _word().toLowerCase();
    if (op == 'pr') return TomScimComparison(attribute, 'pr', null);
    const operators = {'eq', 'ne', 'co', 'sw', 'ew', 'gt', 'ge', 'lt', 'le'};
    if (!operators.contains(op)) throw _error('unknown operator "$op"');
    return TomScimComparison(
      attribute,
      op,
      _value(),
      caseExact: _caseExact.contains(attribute.toLowerCase()),
    );
  }

  Object? _value() {
    _skip();
    if (_peekChar('"')) {
      final start = _at;
      _at++;
      while (_at < text.length && text[_at] != '"') {
        if (text[_at] == '\\') _at++;
        _at++;
      }
      if (_at >= text.length) throw _error('unterminated string');
      _at++;
      try {
        return jsonDecode(text.substring(start, _at));
      } on FormatException {
        throw _error('malformed string');
      }
    }
    final word = _word();
    switch (word.toLowerCase()) {
      case 'true':
        return true;
      case 'false':
        return false;
      case 'null':
        return null;
    }
    final number = num.tryParse(word);
    if (number == null) throw _error('"$word" is not a value');
    return number;
  }

  /// [word] without the resource type's core schema prefix. An extension
  /// attribute keeps its prefix — `urn:…:enterprise:2.0:User:manager` —
  /// which [scimValues] reads as the attribute inside the extension object.
  String _attributeName(String word) {
    if (!word.toLowerCase().startsWith('urn:')) return word;
    final split = word.lastIndexOf(':');
    final schema = word.substring(0, split);
    final attribute = word.substring(split + 1);
    if (schema.toLowerCase() == type.schema.toLowerCase()) return attribute;
    return word;
  }

  TomScimPath _path() {
    _skip();
    final start = _at;
    while (_at < text.length && text[_at] != '[') {
      _at++;
    }
    var head = text.substring(start, _at).trim();
    String? schema;
    if (head.toLowerCase().startsWith('urn:')) {
      // The URN ends at the last colon; the attribute after it may be dotted.
      final split = head.lastIndexOf(':');
      final urn = head.substring(0, split);
      head = head.substring(split + 1);
      if (urn.toLowerCase() != type.schema.toLowerCase()) schema = urn;
    }
    if (head.isEmpty) throw _error('no attribute');
    String attribute = head;
    String? sub;
    TomScimFilter? filter;
    if (_at < text.length && text[_at] == '[') {
      _at++;
      final inner = _Parser(text, type, path: false).._at = _at;
      filter = inner._or();
      _at = inner._at;
      _expectChar(']');
      if (_peekChar('.')) {
        _at++;
        sub = _word();
      }
    } else if (head.contains('.')) {
      final dot = head.indexOf('.');
      attribute = head.substring(0, dot);
      sub = head.substring(dot + 1);
    }
    if (attribute.contains('.') || (sub?.contains('.') ?? false)) {
      throw _error('a path reaches at most one sub-attribute');
    }
    return TomScimPath(
      attribute,
      schema: schema,
      filter: filter,
      subAttribute: sub,
    );
  }
}
