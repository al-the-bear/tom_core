library;

// ---------------------------------------------------------------------------
// TomDateTimeFormat — format / parse engine for text-input date/time fields.
//
// Format tokens (case-sensitive):
//
//   Date
//   YYYY  4-digit year (e.g. 2026)      YY   2-digit year (e.g. 26)
//   MM    month with leading zero        M    month without leading zero
//   DD    day with leading zero          D    day without leading zero
//
//   Time
//   HH    hour 24 h with leading zero    H    hour without leading zero
//   mm    minutes with leading zero      m    minutes without leading zero
//   ss    seconds with leading zero      s    seconds without leading zero
//
// Any other character in the pattern is treated as a literal separator.
//
// Example patterns
//   'YYYY-MM-DD'          ISO date          → 2026-05-12
//   'DD/MM/YYYY'          European date     → 12/05/2026
//   'MM/DD/YYYY'          US date           → 05/12/2026
//   'DD.MM.YYYY'          German date       → 12.05.2026
//   'YYYY-MM-DD HH:mm'    ISO datetime      → 2026-05-12 09:30
//   'DD/MM/YYYY HH:mm'    European datetime → 12/05/2026 09:30
//   'MM/DD/YYYY HH:mm'    US datetime       → 05/12/2026 09:30
//   'HH:mm'               24-hour time      → 09:30
//   'HH:mm:ss'            24-hour with secs → 09:30:00
//
// Resource configuration
//   A field can override the format through the resource system by placing
//   the pattern string at the key `{fieldBasePath}.dateFormat`,
//   `{fieldBasePath}.timeFormat`, or `{fieldBasePath}.dateTimeFormat`.
//   That resource key takes priority over the constructor parameter.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart' show TimeOfDay;

/// Format and parse engine for text-input date/time fields.
///
/// Construct with a pattern string — see file header for token reference.
/// Use the built-in [presets] for the most common international formats.
class TomDateTimeFormat {
  /// The format pattern string (machine-readable, used for parsing and formatting).
  final String pattern;

  /// Optional localised display pattern shown to the user as a hint in the
  /// text field.  When `null`, [hintText] falls back to [pattern].
  ///
  /// Example: pattern `'DD.MM.YYYY'` with displayPattern `'TT.MM.JJJJ'`
  /// keeps the same parsing logic but shows German placeholder letters.
  final String? displayPattern;

  const TomDateTimeFormat(this.pattern, {this.displayPattern});

  // ── Common presets ────────────────────────────────────────────────────────

  /// ISO 8601 date: `YYYY-MM-DD` (e.g. `2026-05-12`)
  static const isoDate = TomDateTimeFormat('YYYY-MM-DD');

  /// European date: `DD/MM/YYYY` (e.g. `12/05/2026`)
  static const europeanDate = TomDateTimeFormat('DD/MM/YYYY');

  /// US date: `MM/DD/YYYY` (e.g. `05/12/2026`)
  static const usDate = TomDateTimeFormat('MM/DD/YYYY');

  /// German/Austrian date: `DD.MM.YYYY` (e.g. `12.05.2026`)
  /// Hint shows `TT.MM.JJJJ` (Tag / Monat / Jahr).
  static const germanDate =
      TomDateTimeFormat('DD.MM.YYYY', displayPattern: 'TT.MM.JJJJ');

  /// ISO 8601 datetime: `YYYY-MM-DD HH:mm` (e.g. `2026-05-12 09:30`)
  static const isoDateTime = TomDateTimeFormat('YYYY-MM-DD HH:mm');

  /// European datetime: `DD/MM/YYYY HH:mm` (e.g. `12/05/2026 09:30`)
  static const europeanDateTime = TomDateTimeFormat('DD/MM/YYYY HH:mm');

  /// US datetime: `MM/DD/YYYY HH:mm` (e.g. `05/12/2026 09:30`)
  static const usDateTime = TomDateTimeFormat('MM/DD/YYYY HH:mm');

  /// 24-hour time: `HH:mm` (e.g. `09:30`)
  static const time24 = TomDateTimeFormat('HH:mm');

  /// 24-hour time with seconds: `HH:mm:ss` (e.g. `09:30:00`)
  static const time24WithSeconds = TomDateTimeFormat('HH:mm:ss');

  // ── Hint text ─────────────────────────────────────────────────────────────

  /// The placeholder hint shown to the user in empty text fields.
  ///
  /// Returns [displayPattern] when set, otherwise falls back to [pattern].
  /// This allows localised placeholder letters (e.g. `TT.MM.JJJJ` in German)
  /// while the underlying parsing pattern stays language-neutral.
  String get hintText => displayPattern ?? pattern;

  // ── Tokeniser ─────────────────────────────────────────────────────────────

  // Alternation order is significant: longer tokens must precede shorter
  // ones so YYYY is matched before YY, MM before M, etc.
  static final _tokenRe =
      RegExp(r'YYYY|YY|MM|M|DD|D|HH|H|mm|m|ss|s|.');

  // ── Formatting ────────────────────────────────────────────────────────────

  /// Formats [d] using the date tokens in [pattern].
  ///
  /// The clock components are supplied as well even though the method is named
  /// for dates: a [DateTime] genuinely carries them, and a pattern that mixes
  /// in `HH:mm` — which a `dateFormat` resource is free to do — would otherwise
  /// render the token names as literal text and produce output that cannot be
  /// parsed back. A pure date pattern is unaffected.
  String formatDate(DateTime d) => _render(
        year: d.year,
        month: d.month,
        day: d.day,
        hour: d.hour,
        minute: d.minute,
        second: d.second,
      );

  /// Formats [t] using the time tokens in [pattern].
  ///
  /// Seconds are zero rather than absent: a [TimeOfDay] is a whole-minute
  /// value, so its second *is* known to be `0`. Leaving it unset made the
  /// shipped [time24WithSeconds] preset render `09:03:ss`. Date tokens stay
  /// unfilled because a time carries no date to fill them with.
  String formatTime(TimeOfDay t) =>
      _render(hour: t.hour, minute: t.minute, second: 0);

  /// Formats [d] using all tokens in [pattern].
  String formatDateTime(DateTime d) => _render(
        year: d.year,
        month: d.month,
        day: d.day,
        hour: d.hour,
        minute: d.minute,
        second: d.second,
      );

  String _render({
    int? year,
    int? month,
    int? day,
    int? hour,
    int? minute,
    int? second,
  }) {
    final buf = StringBuffer();
    for (final tok in _tokenRe.allMatches(pattern)) {
      switch (tok.group(0)) {
        case 'YYYY':
          buf.write(year != null
              ? year.toString().padLeft(4, '0')
              : 'YYYY');
        case 'YY':
          buf.write(year != null
              ? (year % 100).toString().padLeft(2, '0')
              : 'YY');
        case 'MM':
          buf.write(month != null
              ? month.toString().padLeft(2, '0')
              : 'MM');
        case 'M':
          buf.write(month?.toString() ?? 'M');
        case 'DD':
          buf.write(day != null ? day.toString().padLeft(2, '0') : 'DD');
        case 'D':
          buf.write(day?.toString() ?? 'D');
        case 'HH':
          buf.write(hour != null ? hour.toString().padLeft(2, '0') : 'HH');
        case 'H':
          buf.write(hour?.toString() ?? 'H');
        case 'mm':
          buf.write(minute != null
              ? minute.toString().padLeft(2, '0')
              : 'mm');
        case 'm':
          buf.write(minute?.toString() ?? 'm');
        case 'ss':
          buf.write(second != null
              ? second.toString().padLeft(2, '0')
              : 'ss');
        case 's':
          buf.write(second?.toString() ?? 's');
        default:
          buf.write(tok.group(0)); // literal separator
      }
    }
    return buf.toString();
  }

  // ── Parsing ───────────────────────────────────────────────────────────────

  // Parser cache keyed by identity — lives outside the instance so the class
  // can have a const constructor despite lazy initialisation.
  static final _parserCache = Expando<_Parser>();
  _Parser get _cachedParser => _parserCache[this] ??= _Parser.from(pattern);

  /// Parses a date string.  Returns `null` when the text does not match the
  /// pattern or the resulting date falls outside [firstDate]..[lastDate].
  DateTime? parseDate(
    String text, {
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    final v = _cachedParser.parse(text.trim());
    if (v == null) return null;
    final year = v['year'] ?? v['year2'].map((y) => 2000 + y);
    final month = v['month'];
    final day = v['day'];
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    try {
      final date = DateTime(year, month, day);
      if (date.isBefore(firstDate) || date.isAfter(lastDate)) return null;
      return date;
    } catch (_) {
      return null;
    }
  }

  /// Parses a time string. Returns `null` on mismatch or out-of-range values.
  TimeOfDay? parseTime(String text) {
    final v = _cachedParser.parse(text.trim());
    if (v == null) return null;
    final hour = v['hour'];
    final minute = v['minute'];
    if (hour == null || minute == null) return null;
    if (hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Parses a date+time string. Returns `null` when the text does not match
  /// or the resulting datetime is outside [firstDate]..[lastDate].
  DateTime? parseDateTime(
    String text, {
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    final v = _cachedParser.parse(text.trim());
    if (v == null) return null;
    final year = v['year'] ?? v['year2'].map((y) => 2000 + y);
    final month = v['month'];
    final day = v['day'];
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final hour = v['hour'] ?? 0;
    final minute = v['minute'] ?? 0;
    final second = v['second'] ?? 0;
    if (hour > 23 || minute > 59 || second > 59) return null;
    try {
      final dt = DateTime(year, month, day, hour, minute, second);
      if (dt.isBefore(firstDate) || dt.isAfter(lastDate)) return null;
      return dt;
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Internal parser — compiled once per format pattern.
// ---------------------------------------------------------------------------

/// A lazily compiled regex + field-index map derived from a [TomDateTimeFormat]
/// pattern.  Reused for every parse call on the same format.
class _Parser {
  final RegExp _regex;

  /// Maps field name → 1-based capture group index.
  final Map<String, int> _groups;

  _Parser._(this._regex, this._groups);

  factory _Parser.from(String pattern) {
    final regexBuf = StringBuffer('^');
    int groupIdx = 1;
    final groups = <String, int>{};

    void addGroup(String field, String capturePattern) {
      if (!groups.containsKey(field)) {
        groups[field] = groupIdx++;
        regexBuf.write('($capturePattern)');
      } else {
        // Duplicate token — match without capturing (shouldn't appear in
        // well-formed patterns but handle gracefully).
        regexBuf.write(capturePattern);
      }
    }

    for (final tok in TomDateTimeFormat._tokenRe.allMatches(pattern)) {
      switch (tok.group(0)) {
        case 'YYYY':
          addGroup('year', r'\d{4}');
        case 'YY':
          addGroup('year2', r'\d{2}');
        case 'MM':
        case 'M':
          addGroup('month', r'\d{1,2}');
        case 'DD':
        case 'D':
          addGroup('day', r'\d{1,2}');
        case 'HH':
        case 'H':
          addGroup('hour', r'\d{1,2}');
        case 'mm':
        case 'm':
          addGroup('minute', r'\d{1,2}');
        case 'ss':
        case 's':
          addGroup('second', r'\d{1,2}');
        default:
          regexBuf.write(RegExp.escape(tok.group(0)!));
      }
    }
    regexBuf.write(r'$');
    return _Parser._(RegExp(regexBuf.toString()), groups);
  }

  /// Returns a map of field name → parsed integer value, or `null` if the
  /// text does not match the compiled regex.
  Map<String, int>? parse(String text) {
    final m = _regex.firstMatch(text);
    if (m == null) return null;
    final result = <String, int>{};
    for (final entry in _groups.entries) {
      final raw = m.group(entry.value);
      if (raw != null) result[entry.key] = int.parse(raw);
    }
    return result;
  }
}

// Convenience extension so nullable int lookups stay readable.
extension _NullableInt on int? {
  int? map(int Function(int) f) => this == null ? null : f(this!);
}
