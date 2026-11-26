/// Reading a Dart source file far enough to find its string literals and
/// the code around them, without a parser.
///
/// The coverage check needs three things from a file: every string literal
/// with its place and value, the code with comments and literals blanked out
/// (so a pattern such as `tomId:` is never found inside a comment or a text),
/// and, for a literal, the call it is an argument of. A full Dart parser
/// would answer all three, but the analyzer is a heavy dependency for a test
/// helper and is pinned differently by Flutter's test framework; the lexical
/// level is enough, because ids are written as plain literals by rule.
library;

/// One string literal of a source file.
class DartStringLiteral {
  DartStringLiteral({
    required this.start,
    required this.end,
    required this.value,
    required this.interpolated,
    required this.line,
  });

  /// Offset of the literal's first character (its `r` prefix or quote).
  final int start;

  /// Offset just after its closing quote.
  final int end;

  /// Its text with escapes resolved; every interpolation (`$x`, `${...}`)
  /// is replaced by [interpolationMark].
  final String value;

  /// Whether it holds an interpolation.
  final bool interpolated;

  /// The 1-based line it starts on.
  final int line;

  /// What an interpolation reads as in [value].
  static const interpolationMark = '\u0000';

  @override
  String toString() => 'DartStringLiteral(line $line: $value)';
}

/// A Dart source file, lexed into its string literals and its code.
class DartSource {
  DartSource._(this.text, this.masked, this.literals, this._lineStarts);

  /// Lexes [text].
  factory DartSource.parse(String text) {
    final lexer = _Lexer(text)..run();
    final lineStarts = <int>[0];
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 0x0A) lineStarts.add(i + 1);
    }
    final source = DartSource._(
      text,
      String.fromCharCodes(lexer.masked),
      const [],
      lineStarts,
    );
    return DartSource._(text, source.masked, [
      for (final raw in lexer.literals)
        DartStringLiteral(
          start: raw.start,
          end: raw.end,
          value: raw.value,
          interpolated: raw.interpolated,
          line: source.lineOf(raw.start),
        ),
    ], lineStarts);
  }

  /// The source as it was read.
  final String text;

  /// The source with every comment replaced by spaces and every string
  /// literal (quotes, prefix and content, interpolations included) by
  /// [literalMark], line breaks kept: the code alone, at the same offsets.
  final String masked;

  /// Every string literal, in source order; a literal inside another's
  /// interpolation is listed too, after the outer one.
  final List<DartStringLiteral> literals;

  final List<int> _lineStarts;

  /// What a string literal's characters read as in [masked]: neither space
  /// nor part of an identifier, so a pattern never runs into or across one.
  static const literalMark = 0xA7; // the section sign

  /// The 1-based line of [offset].
  int lineOf(int offset) {
    var low = 0;
    var high = _lineStarts.length - 1;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (_lineStarts[mid] <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low + 1;
  }

  /// The literal that starts at [offset], or null.
  DartStringLiteral? literalAt(int offset) {
    for (final literal in literals) {
      if (literal.start == offset) return literal;
      if (literal.start > offset) break;
    }
    return null;
  }

  /// The literal whose span holds [offset] (the outermost one), or null.
  DartStringLiteral? literalAround(int offset) {
    for (final literal in literals) {
      if (literal.start <= offset && offset < literal.end) return literal;
      if (literal.start > offset) break;
    }
    return null;
  }

  /// The name of the call whose argument list holds [offset]: the
  /// identifier chain before the innermost unclosed `(` (`print`,
  /// `tomLog.warn`, `StateError`, `ForgeText.literal`), or null when the
  /// offset is in no argument list. A list or map literal or a block between
  /// is passed over, so a literal inside `[...]` or `{...}` of a call's
  /// argument still names that call.
  String? enclosingCall(int offset) {
    final stack = <int>[];
    for (var i = offset - 1; i >= 0; i--) {
      final c = masked.codeUnitAt(i);
      if (c == 0x29 || c == 0x5D || c == 0x7D) {
        stack.add(c);
      } else if (c == 0x28 || c == 0x5B || c == 0x7B) {
        if (stack.isNotEmpty) {
          stack.removeLast();
          continue;
        }
        if (c != 0x28) continue;
        return _nameBefore(i);
      } else if (c == 0x3B && stack.isEmpty) {
        // A statement ends here: whatever holds the offset starts after it.
        return null;
      }
    }
    return null;
  }

  /// The identifier chain that ends just before [index], spaces and type
  /// arguments skipped (`List<String>.of` reads `List.of`), or null.
  String? _nameBefore(int index) {
    var i = index - 1;
    final parts = <String>[];
    while (i >= 0 && _isSpace(masked.codeUnitAt(i))) {
      i--;
    }
    while (i >= 0) {
      final c = masked.codeUnitAt(i);
      if (c == 0x3E) {
        // Type arguments: skip to their `<`.
        var depth = 0;
        for (; i >= 0; i--) {
          final d = masked.codeUnitAt(i);
          if (d == 0x3E) depth++;
          if (d == 0x3C && --depth == 0) {
            i--;
            break;
          }
        }
        continue;
      }
      if (_isIdentifierPart(c) || c == 0x2E) {
        final end = i + 1;
        while (i >= 0 &&
            (_isIdentifierPart(masked.codeUnitAt(i)) ||
                masked.codeUnitAt(i) == 0x2E)) {
          i--;
        }
        parts.add(masked.substring(i + 1, end));
        continue;
      }
      break;
    }
    final name = parts.reversed.join();
    return name.isEmpty ? null : name;
  }

  /// The offset of the `)` that closes the argument list open at
  /// [afterOpen] (just after its `(`), or the end of the file.
  int closingParen(int afterOpen) {
    var depth = 1;
    for (var i = afterOpen; i < masked.length; i++) {
      final c = masked.codeUnitAt(i);
      if (c == 0x28 || c == 0x5B || c == 0x7B) depth++;
      if (c == 0x29 || c == 0x5D || c == 0x7D) {
        depth--;
        if (depth == 0) return i;
      }
    }
    return masked.length;
  }

  static bool _isSpace(int c) => c == 0x20 || c == 0x0A || c == 0x0D || c == 9;

  static bool _isIdentifierPart(int c) =>
      (c >= 0x30 && c <= 0x39) ||
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x61 && c <= 0x7A) ||
      c == 0x5F ||
      c == 0x24;
}

class _RawLiteral {
  _RawLiteral(this.start, this.end, this.value, this.interpolated);

  final int start;
  final int end;
  final String value;
  final bool interpolated;
}

/// The lexer: walks the text once, blanking comments and literals into
/// [masked] and collecting [literals].
class _Lexer {
  _Lexer(this.text) : masked = text.codeUnits.toList();

  final String text;
  final List<int> masked;
  final List<_RawLiteral> literals = [];

  void run() => _code(0, untilBrace: false);

  /// Lexes code from [start]; with [untilBrace], up to the `}` that closes
  /// an interpolation, whose offset it answers.
  int _code(int start, {required bool untilBrace}) {
    var i = start;
    var depth = 0;
    while (i < text.length) {
      final c = text.codeUnitAt(i);
      if (c == 0x2F && i + 1 < text.length) {
        final next = text.codeUnitAt(i + 1);
        if (next == 0x2F) {
          i = _lineComment(i);
          continue;
        }
        if (next == 0x2A) {
          i = _blockComment(i);
          continue;
        }
      }
      if (c == 0x22 || c == 0x27) {
        i = _string(i, i, raw: false);
        continue;
      }
      if ((c == 0x72 || c == 0x52) &&
          i + 1 < text.length &&
          (text.codeUnitAt(i + 1) == 0x22 || text.codeUnitAt(i + 1) == 0x27) &&
          (i == 0 || !DartSource._isIdentifierPart(text.codeUnitAt(i - 1)))) {
        i = _string(i, i + 1, raw: true);
        continue;
      }
      if (untilBrace) {
        if (c == 0x7B) depth++;
        if (c == 0x7D) {
          if (depth == 0) return i;
          depth--;
        }
      }
      i++;
    }
    return i;
  }

  int _lineComment(int start) {
    var i = start;
    while (i < text.length && text.codeUnitAt(i) != 0x0A) {
      masked[i] = 0x20;
      i++;
    }
    return i;
  }

  int _blockComment(int start) {
    var i = start + 2;
    var depth = 1;
    while (i < text.length && depth > 0) {
      if (text.startsWith('/*', i)) {
        depth++;
        i += 2;
      } else if (text.startsWith('*/', i)) {
        depth--;
        i += 2;
      } else {
        i++;
      }
    }
    _blank(start, i);
    return i;
  }

  void _blank(int start, int end, {int fill = 0x20}) {
    for (var j = start; j < end && j < text.length; j++) {
      if (text.codeUnitAt(j) != 0x0A) masked[j] = fill;
    }
  }

  /// Lexes the literal starting at [start] whose opening quote is at
  /// [quoteAt]; answers the offset after it.
  int _string(int start, int quoteAt, {required bool raw}) {
    final quote = text.codeUnitAt(quoteAt);
    final triple =
        text.length >= quoteAt + 3 &&
        text.codeUnitAt(quoteAt + 1) == quote &&
        text.codeUnitAt(quoteAt + 2) == quote;
    final delimiter = String.fromCharCodes(List.filled(triple ? 3 : 1, quote));
    var i = quoteAt + delimiter.length;
    final value = StringBuffer();
    var interpolated = false;
    final nested = <_RawLiteral>[];
    while (i < text.length) {
      if (text.startsWith(delimiter, i)) {
        i += delimiter.length;
        break;
      }
      final c = text.codeUnitAt(i);
      if (!triple && c == 0x0A) break; // unterminated: stop at the line end
      if (!raw && c == 0x5C && i + 1 < text.length) {
        value.write(_escape(text[i + 1]));
        i += 2;
        continue;
      }
      if (!raw && c == 0x24 && i + 1 < text.length) {
        final next = text.codeUnitAt(i + 1);
        if (next == 0x7B) {
          interpolated = true;
          value.write(DartStringLiteral.interpolationMark);
          final before = literals.length;
          final close = _code(i + 2, untilBrace: true);
          nested.addAll(literals.sublist(before));
          literals.removeRange(before, literals.length);
          i = close + 1;
          continue;
        }
        if (DartSource._isIdentifierPart(next) && next != 0x24) {
          interpolated = true;
          value.write(DartStringLiteral.interpolationMark);
          i++;
          while (i < text.length &&
              DartSource._isIdentifierPart(text.codeUnitAt(i)) &&
              text.codeUnitAt(i) != 0x24) {
            i++;
          }
          continue;
        }
      }
      value.write(text[i]);
      i++;
    }
    literals
      ..add(_RawLiteral(start, i, value.toString(), interpolated))
      ..addAll(nested);
    _blank(start, i, fill: DartSource.literalMark);
    return i;
  }

  static String _escape(String c) => switch (c) {
    'n' => '\n',
    't' => '\t',
    'r' => '\r',
    'b' => '\b',
    'f' => '\f',
    'v' => '\v',
    _ => c,
  };
}
