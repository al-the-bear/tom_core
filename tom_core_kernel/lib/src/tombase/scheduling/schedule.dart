/// Schedule expressions — the *when* half of a background job.
///
/// A CE-JB job declares a trigger of one of three kinds (`cron | calendar |
/// event`). This library turns each of those into something the scheduler can
/// ask a single question of: **given that I last considered the world at time
/// T, when does this job next want to run?**
///
/// That question — [TomSchedule.nextFireAfter] — is deliberately the whole
/// contract. A schedule computes fire *times*; it never holds a timer, never
/// touches a clock of its own, and never knows whether a computed window
/// actually ran. All of that belongs to the scheduler, which means a schedule
/// is a pure function and can be tested by evaluating it against fixed dates
/// with no waiting and no fakes.
///
/// ## The shipped schedules
///
/// * [TomCronSchedule] — the standard five-field POSIX cron expression, for
///   "at these minutes of these hours of these days".
/// * [TomCalendarSchedule] — recurrences cron *cannot* express, which is
///   exactly why it is a separate kind rather than a second spelling of the
///   first: last-day-of-month, and the nth (or last) weekday of a month.
/// * [TomIntervalSchedule] — a fixed period from an anchor, for cadences that
///   are not aligned to the wall clock at all ("every 90 seconds").
/// * [TomOnceSchedule] — a single absolute instant, then never again. The only
///   non-recurring clock-driven schedule, and the one that expresses a deadline
///   or a timer wait.
/// * [TomEventSchedule] — not clock-driven. It answers `null` to every
///   [TomSchedule.nextFireAfter] and instead exposes a [Stream]; the scheduler
///   subscribes and enqueues a run per event.
///
/// ## Time zones
///
/// Every schedule preserves the UTC-ness of the [DateTime] it is asked about:
/// evaluate against a local `DateTime` and you get wall-clock semantics
/// (including the DST discontinuities a wall-clock schedule inherently has);
/// evaluate against a UTC `DateTime` and you get a DST-immune absolute
/// cadence. The schedule does not decide which you want — the scheduler's
/// clock does.
///
/// [TomOnceSchedule] is the exception that proves the rule: it names one
/// absolute instant rather than a wall-clock position, so there is nothing for
/// a zone to change. It still answers in [from]'s zone, but only because the
/// contract says the answer is comparable to the question.
library;

import '../little_things/exception_base.dart';

// =============================================================================
// EXCEPTIONS
// =============================================================================

/// Thrown when a schedule expression cannot be parsed or is self-contradictory.
class TomScheduleException extends TomException {
  /// Creates a [TomScheduleException] with the given error details.
  TomScheduleException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.uuid,
    super.serverCallError,
  });
}

// =============================================================================
// SCHEDULE CONTRACT
// =============================================================================

/// A job trigger, reduced to the one question the scheduler asks of it.
///
/// Implementations must be **pure**: [nextFireAfter] may not read a clock, and
/// two calls with the same argument must return the same answer. The scheduler
/// relies on that to replay windows deterministically after a restart.
abstract class TomSchedule {
  /// Creates a schedule.
  const TomSchedule();

  /// The first fire time **strictly after** [from], or `null` when this
  /// schedule will never fire again.
  ///
  /// `null` is a real answer, not an error: `0 0 30 2 *` (February 30th) can
  /// never match, and an [TomEventSchedule] is never clock-due. Callers must
  /// treat it as "stop asking", not as a failure.
  ///
  /// The returned value is in the same zone as [from] — UTC in, UTC out.
  DateTime? nextFireAfter(DateTime from);

  /// Whether the scheduler should poll this schedule for due windows.
  ///
  /// `false` for [TomEventSchedule], whose runs arrive from a source instead.
  bool get isClockDriven => true;

  /// A short human-readable form, used in logs and alerts.
  String describe();

  @override
  String toString() => describe();
}

// =============================================================================
// CRON
// =============================================================================

/// A standard five-field POSIX cron expression.
///
/// ```text
/// ┌───────── minute        (0-59)
/// │ ┌─────── hour          (0-23)
/// │ │ ┌───── day of month  (1-31)
/// │ │ │ ┌─── month         (1-12 or JAN-DEC)
/// │ │ │ │ ┌─ day of week   (0-7 or SUN-SAT, both 0 and 7 mean Sunday)
/// * * * * *
/// ```
///
/// Each field accepts `*`, a single value, a `low-high` range, a comma-separated
/// list of either, and a `/step` suffix on `*` or on a range (`*/15`, `1-10/2`).
/// Month and day-of-week names are accepted case-insensitively.
///
/// ## Two behaviours worth knowing before you write an expression
///
/// **Day-of-month and day-of-week are OR-ed, not AND-ed.** This is POSIX
/// behaviour and it surprises people every time: when *both* fields are
/// restricted, the expression fires on a day matching *either*. `0 0 1 * MON`
/// is "midnight on the 1st, **and** every Monday" — not "the 1st when it is a
/// Monday". When only one of the two is restricted, only that one applies.
/// [TomCalendarSchedule] exists partly so that intersecting rules have a
/// spelling that means what it looks like.
///
/// **There is no seconds field.** Not on either end — a six-field expression is
/// rejected rather than guessed at, because the two common conventions put
/// seconds at opposite ends and a misread expression fires 60× too often. A
/// sub-minute cadence is [TomIntervalSchedule]'s job.
///
/// ## Macros
///
/// `@yearly`/`@annually`, `@monthly`, `@weekly`, `@daily`/`@midnight` and
/// `@hourly` expand to their conventional expressions.
class TomCronSchedule extends TomSchedule {
  /// How far ahead [nextFireAfter] searches before concluding "never".
  ///
  /// Four years so that a February 29th expression resolves rather than
  /// reporting `null` on a common year.
  static const int _searchYears = 5;

  static const Map<String, String> _macros = {
    '@yearly': '0 0 1 1 *',
    '@annually': '0 0 1 1 *',
    '@monthly': '0 0 1 * *',
    '@weekly': '0 0 * * 0',
    '@daily': '0 0 * * *',
    '@midnight': '0 0 * * *',
    '@hourly': '0 * * * *',
  };

  static const Map<String, int> _monthNames = {
    'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
    'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
  };

  static const Map<String, int> _dayNames = {
    'SUN': 0, 'MON': 1, 'TUE': 2, 'WED': 3, 'THU': 4, 'FRI': 5, 'SAT': 6,
  };

  /// The expression this schedule was parsed from, kept for [describe].
  final String expression;

  final Set<int> _minutes;
  final Set<int> _hours;
  final Set<int> _daysOfMonth;
  final Set<int> _months;
  final Set<int> _daysOfWeek;

  /// Whether the day-of-month field was `*` — decides the OR/AND question.
  final bool _dayOfMonthWildcard;

  /// Whether the day-of-week field was `*` — decides the OR/AND question.
  final bool _dayOfWeekWildcard;

  TomCronSchedule._(
    this.expression,
    this._minutes,
    this._hours,
    this._daysOfMonth,
    this._months,
    this._daysOfWeek,
    this._dayOfMonthWildcard,
    this._dayOfWeekWildcard,
  );

  /// Parses [expression], throwing [TomScheduleException] if it is not a valid
  /// five-field cron expression or a supported `@macro`.
  factory TomCronSchedule(String expression) {
    final trimmed = expression.trim();
    if (trimmed.isEmpty) {
      throw TomScheduleException(
        'schedule.cron.empty',
        'A cron expression cannot be empty.',
      );
    }
    final expanded = _macros[trimmed.toLowerCase()] ?? trimmed;
    final fields = expanded.split(RegExp(r'\s+'));
    if (fields.length != 5) {
      throw TomScheduleException(
        'schedule.cron.field_count',
        'A cron expression needs exactly 5 fields '
            '(minute hour day-of-month month day-of-week); '
            'got ${fields.length} in "$expression". '
            'Seconds are not supported — use TomIntervalSchedule.',
        parameters: {'expression': expression},
      );
    }

    final minutes = _parseField(fields[0], 0, 59, expression, 'minute');
    final hours = _parseField(fields[1], 0, 23, expression, 'hour');
    final daysOfMonth =
        _parseField(fields[2], 1, 31, expression, 'day-of-month');
    final months =
        _parseField(fields[3], 1, 12, expression, 'month', _monthNames);
    final daysOfWeek =
        _parseField(fields[4], 0, 7, expression, 'day-of-week', _dayNames);

    return TomCronSchedule._(
      trimmed,
      minutes,
      hours,
      daysOfMonth,
      months,
      // Both 0 and 7 spell Sunday; normalise so matching only has to check 0.
      daysOfWeek.map((d) => d == 7 ? 0 : d).toSet(),
      _isWildcard(fields[2]),
      _isWildcard(fields[4]),
    );
  }

  static bool _isWildcard(String field) =>
      field == '*' || field.startsWith('*/');

  /// Expands one cron field into the concrete set of values it matches.
  static Set<int> _parseField(
    String field,
    int min,
    int max,
    String expression,
    String fieldName, [
    Map<String, int>? names,
  ]) {
    final values = <int>{};
    for (final item in field.split(',')) {
      _parseItem(item.trim(), min, max, expression, fieldName, names, values);
    }
    if (values.isEmpty) {
      throw TomScheduleException(
        'schedule.cron.empty_field',
        'The $fieldName field of "$expression" matches nothing.',
        parameters: {'expression': expression, 'field': fieldName},
      );
    }
    return values;
  }

  static void _parseItem(
    String item,
    int min,
    int max,
    String expression,
    String fieldName,
    Map<String, int>? names,
    Set<int> into,
  ) {
    if (item.isEmpty) {
      throw _fieldError(expression, fieldName, 'empty list entry');
    }

    var step = 1;
    var body = item;
    final slash = item.indexOf('/');
    if (slash >= 0) {
      body = item.substring(0, slash);
      final stepText = item.substring(slash + 1);
      final parsed = int.tryParse(stepText);
      if (parsed == null || parsed <= 0) {
        throw _fieldError(
          expression,
          fieldName,
          'step "$stepText" must be a positive integer',
        );
      }
      step = parsed;
    }

    int low;
    int high;
    if (body == '*') {
      low = min;
      high = max;
    } else if (body.contains('-')) {
      final bounds = body.split('-');
      if (bounds.length != 2) {
        throw _fieldError(expression, fieldName, 'malformed range "$body"');
      }
      low = _value(bounds[0], min, max, expression, fieldName, names);
      high = _value(bounds[1], min, max, expression, fieldName, names);
      if (low > high) {
        throw _fieldError(
          expression,
          fieldName,
          'range "$body" runs backwards; wrap-around ranges are not supported',
        );
      }
    } else {
      low = _value(body, min, max, expression, fieldName, names);
      // A bare value with a step (`5/10`) means "from 5 onwards, every 10".
      high = slash >= 0 ? max : low;
    }

    for (var v = low; v <= high; v += step) {
      into.add(v);
    }
  }

  static int _value(
    String text,
    int min,
    int max,
    String expression,
    String fieldName,
    Map<String, int>? names,
  ) {
    final named = names?[text.toUpperCase()];
    final value = named ?? int.tryParse(text);
    if (value == null) {
      throw _fieldError(expression, fieldName, 'unrecognised value "$text"');
    }
    if (value < min || value > max) {
      throw _fieldError(
        expression,
        fieldName,
        'value $value is outside $min-$max',
      );
    }
    return value;
  }

  static TomScheduleException _fieldError(
    String expression,
    String fieldName,
    String problem,
  ) =>
      TomScheduleException(
        'schedule.cron.invalid_field',
        'The $fieldName field of "$expression" is invalid: $problem.',
        parameters: {'expression': expression, 'field': fieldName},
      );

  @override
  DateTime? nextFireAfter(DateTime from) {
    // Cron resolves to whole minutes, so the search starts at the minute after
    // `from` — truncating first, so a `from` of 10:30:45 does not skip 10:31.
    var candidate = _at(from, from.year, from.month, from.day, from.hour,
        from.minute + 1);
    final limit = _at(from, from.year + _searchYears, from.month, from.day);

    // Coarse-to-fine: an unmatched month skips a whole month rather than
    // 40 000 minutes, which is what keeps a rare expression (Feb 29th) cheap.
    while (candidate.isBefore(limit)) {
      if (!_months.contains(candidate.month)) {
        candidate = _at(candidate, candidate.year, candidate.month + 1, 1);
        continue;
      }
      if (!_matchesDay(candidate)) {
        candidate =
            _at(candidate, candidate.year, candidate.month, candidate.day + 1);
        continue;
      }
      if (!_hours.contains(candidate.hour)) {
        candidate = _at(candidate, candidate.year, candidate.month,
            candidate.day, candidate.hour + 1);
        continue;
      }
      if (!_minutes.contains(candidate.minute)) {
        candidate = _at(candidate, candidate.year, candidate.month,
            candidate.day, candidate.hour, candidate.minute + 1);
        continue;
      }
      return candidate;
    }
    return null;
  }

  /// Applies the POSIX day rule: OR when both day fields are restricted,
  /// otherwise whichever one is restricted.
  bool _matchesDay(DateTime candidate) {
    if (_dayOfMonthWildcard && _dayOfWeekWildcard) return true;
    // Dart's weekday is Mon=1..Sun=7; cron's is Sun=0..Sat=6.
    final dowMatch = _daysOfWeek.contains(candidate.weekday % 7);
    final domMatch = _daysOfMonth.contains(candidate.day);
    if (_dayOfMonthWildcard) return dowMatch;
    if (_dayOfWeekWildcard) return domMatch;
    return domMatch || dowMatch;
  }

  @override
  String describe() => 'cron($expression)';
}

// =============================================================================
// CALENDAR
// =============================================================================

/// Which weekday-of-month rule a [TomCalendarSchedule] applies.
enum TomCalendarRule {
  /// A day counted from the start (positive) or end (negative) of the month.
  dayOfMonth,

  /// The nth — or last — occurrence of a weekday within the month.
  weekdayOfMonth,
}

/// Recurrences that cron cannot express.
///
/// This type exists for a narrow reason: cron's day-of-month field counts
/// forward from the 1st and has no way to say "the last day of the month" (the
/// 31st is not the last day of April) or "the second Tuesday". Those two rules
/// cover the great majority of real calendar-driven work — month-end billing,
/// period close, a report on the first Monday — and neither can be written as a
/// cron expression at all.
///
/// Anything cron *can* say should be said with [TomCronSchedule]; having two
/// spellings for one recurrence is how two jobs end up disagreeing about what
/// "daily" means.
class TomCalendarSchedule extends TomSchedule {
  /// How far ahead [nextFireAfter] searches before concluding "never".
  static const int _searchMonths = 60;

  /// Which rule this schedule applies.
  final TomCalendarRule rule;

  /// For [TomCalendarRule.dayOfMonth]: the day, counted from the start of the
  /// month when positive and from its end when negative (`-1` = last day).
  ///
  /// A positive day that does not exist in a given month (the 31st of April)
  /// simply does not fire that month — it is **not** clamped, because a
  /// month-end job that silently ran on the 30th would be indistinguishable
  /// from one that ran on time.
  final int dayOfMonth;

  /// For [TomCalendarRule.weekdayOfMonth]: the weekday, using Dart's
  /// `DateTime.monday`..`DateTime.sunday` (1-7).
  final int weekday;

  /// For [TomCalendarRule.weekdayOfMonth]: which occurrence, `1`-`5` counting
  /// forward or `-1` for the last occurrence in the month.
  final int ordinal;

  /// Every how many months the schedule repeats, counted from [anchorMonth].
  final int monthInterval;

  /// The month-of-year the [monthInterval] cycle is anchored on (1-12).
  final int anchorMonth;

  /// Hour of day the schedule fires at (0-23).
  final int hour;

  /// Minute of the hour the schedule fires at (0-59).
  final int minute;

  const TomCalendarSchedule._({
    required this.rule,
    required this.dayOfMonth,
    required this.weekday,
    required this.ordinal,
    required this.monthInterval,
    required this.anchorMonth,
    required this.hour,
    required this.minute,
  });

  /// Fires on [dayOfMonth] of every [monthInterval]-th month at [hour]:[minute].
  ///
  /// Pass a negative [dayOfMonth] to count from the end of the month: `-1` is
  /// the last day, `-2` the second to last. This is the spelling cron lacks.
  factory TomCalendarSchedule.dayOfMonth(
    int dayOfMonth, {
    int hour = 0,
    int minute = 0,
    int monthInterval = 1,
    int anchorMonth = 1,
  }) {
    if (dayOfMonth == 0 || dayOfMonth > 31 || dayOfMonth < -31) {
      throw TomScheduleException(
        'schedule.calendar.day_of_month',
        'dayOfMonth must be 1..31 or -1..-31 (0 is not a day); got $dayOfMonth.',
        parameters: {'dayOfMonth': dayOfMonth},
      );
    }
    return TomCalendarSchedule._(
      rule: TomCalendarRule.dayOfMonth,
      dayOfMonth: dayOfMonth,
      weekday: DateTime.monday,
      ordinal: 1,
      monthInterval: _checkInterval(monthInterval),
      anchorMonth: _checkMonth(anchorMonth),
      hour: _checkHour(hour),
      minute: _checkMinute(minute),
    );
  }

  /// Fires on the [ordinal]-th [weekday] of every [monthInterval]-th month.
  ///
  /// [weekday] uses Dart's constants (`DateTime.monday`..`DateTime.sunday`).
  /// [ordinal] is `1`-`5`, or `-1` for the last occurrence in the month. A
  /// 5th occurrence that a given month does not have simply does not fire.
  factory TomCalendarSchedule.weekdayOfMonth({
    required int weekday,
    required int ordinal,
    int hour = 0,
    int minute = 0,
    int monthInterval = 1,
    int anchorMonth = 1,
  }) {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) {
      throw TomScheduleException(
        'schedule.calendar.weekday',
        'weekday must be DateTime.monday..DateTime.sunday (1-7); got $weekday.',
        parameters: {'weekday': weekday},
      );
    }
    if (ordinal != -1 && (ordinal < 1 || ordinal > 5)) {
      throw TomScheduleException(
        'schedule.calendar.ordinal',
        'ordinal must be 1..5 or -1 for the last occurrence; got $ordinal.',
        parameters: {'ordinal': ordinal},
      );
    }
    return TomCalendarSchedule._(
      rule: TomCalendarRule.weekdayOfMonth,
      dayOfMonth: 1,
      weekday: weekday,
      ordinal: ordinal,
      monthInterval: _checkInterval(monthInterval),
      anchorMonth: _checkMonth(anchorMonth),
      hour: _checkHour(hour),
      minute: _checkMinute(minute),
    );
  }

  static int _checkInterval(int value) {
    if (value < 1 || value > 12) {
      throw TomScheduleException(
        'schedule.calendar.month_interval',
        'monthInterval must be 1..12; got $value.',
        parameters: {'monthInterval': value},
      );
    }
    return value;
  }

  static int _checkMonth(int value) {
    if (value < 1 || value > 12) {
      throw TomScheduleException(
        'schedule.calendar.anchor_month',
        'anchorMonth must be 1..12; got $value.',
        parameters: {'anchorMonth': value},
      );
    }
    return value;
  }

  static int _checkHour(int value) {
    if (value < 0 || value > 23) {
      throw TomScheduleException(
        'schedule.calendar.hour',
        'hour must be 0..23; got $value.',
        parameters: {'hour': value},
      );
    }
    return value;
  }

  static int _checkMinute(int value) {
    if (value < 0 || value > 59) {
      throw TomScheduleException(
        'schedule.calendar.minute',
        'minute must be 0..59; got $value.',
        parameters: {'minute': value},
      );
    }
    return value;
  }

  @override
  DateTime? nextFireAfter(DateTime from) {
    var year = from.year;
    var month = from.month;
    for (var step = 0; step <= _searchMonths; step++) {
      if (_monthApplies(year, month)) {
        final fire = _fireDateIn(from, year, month);
        if (fire != null && fire.isAfter(from)) return fire;
      }
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
    return null;
  }

  /// Whether [month] is on the [monthInterval] cycle anchored at [anchorMonth].
  bool _monthApplies(int year, int month) {
    if (monthInterval == 1) return true;
    // Absolute month index keeps the cycle continuous across year boundaries,
    // so a quarterly schedule does not restart every January.
    final index = year * 12 + (month - 1);
    final anchor = year * 12 + (anchorMonth - 1);
    return (index - anchor) % monthInterval == 0;
  }

  /// The fire instant within [year]/[month], or `null` when the rule has no
  /// match there (April 31st, a 5th Friday a month does not have).
  DateTime? _fireDateIn(DateTime zoneRef, int year, int month) {
    final lastDay = _daysInMonth(year, month);
    int day;
    if (rule == TomCalendarRule.dayOfMonth) {
      day = dayOfMonth > 0 ? dayOfMonth : lastDay + dayOfMonth + 1;
      if (day < 1 || day > lastDay) return null;
    } else {
      day = _weekdayOccurrence(year, month, lastDay);
      if (day < 1) return null;
    }
    return _at(zoneRef, year, month, day, hour, minute);
  }

  /// The day-of-month of the [ordinal]-th [weekday] in the given month, or
  /// `-1` when the month has no such occurrence.
  int _weekdayOccurrence(int year, int month, int lastDay) {
    if (ordinal == -1) {
      for (var day = lastDay; day >= 1; day--) {
        if (DateTime.utc(year, month, day).weekday == weekday) return day;
      }
      return -1;
    }
    var seen = 0;
    for (var day = 1; day <= lastDay; day++) {
      if (DateTime.utc(year, month, day).weekday == weekday) {
        seen++;
        if (seen == ordinal) return day;
      }
    }
    return -1;
  }

  static int _daysInMonth(int year, int month) =>
      // Day 0 of the following month is the last day of this one, and the
      // DateTime constructor does the leap-year arithmetic for us.
      DateTime.utc(year, month + 1, 0).day;

  @override
  String describe() {
    final time = '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
    final every = monthInterval == 1 ? 'monthly' : 'every $monthInterval months';
    if (rule == TomCalendarRule.dayOfMonth) {
      final which = dayOfMonth > 0
          ? 'day $dayOfMonth'
          : 'day $dayOfMonth from month end';
      return 'calendar($which, $every, $time)';
    }
    final which = ordinal == -1 ? 'last' : 'occurrence $ordinal';
    return 'calendar($which weekday $weekday, $every, $time)';
  }
}

// =============================================================================
// INTERVAL
// =============================================================================

/// A fixed period measured from an anchor instant.
///
/// Use this when the cadence is not aligned to the wall clock — "every 90
/// seconds", "every 45 minutes" — which cron cannot express because its fields
/// are calendar positions, not durations.
///
/// Fire times are computed from [anchor] by whole multiples of [period], not by
/// repeatedly adding to the previous answer, so a scheduler that was down for
/// an hour resumes on the original grid instead of drifting by the outage.
class TomIntervalSchedule extends TomSchedule {
  /// The gap between consecutive fire times.
  final Duration period;

  /// The instant the grid is aligned to. Defaults to the Unix epoch, which
  /// makes fire times reproducible across processes and machines.
  final DateTime anchor;

  /// Creates an interval schedule firing every [period] from [anchor].
  TomIntervalSchedule(this.period, {DateTime? anchor})
      : anchor = anchor ?? DateTime.utc(1970) {
    if (period <= Duration.zero) {
      throw TomScheduleException(
        'schedule.interval.period',
        'An interval schedule needs a positive period; got $period.',
        parameters: {'period': period.toString()},
      );
    }
  }

  @override
  DateTime? nextFireAfter(DateTime from) {
    final micros = period.inMicroseconds;
    final elapsed =
        from.microsecondsSinceEpoch - anchor.microsecondsSinceEpoch;
    // Floor division, then step one grid point on, so the answer is strictly
    // after `from` even when `from` sits exactly on the grid.
    final steps = (elapsed / micros).floor() + 1;
    final fire = anchor.microsecondsSinceEpoch + steps * micros;
    return from.isUtc
        ? DateTime.fromMicrosecondsSinceEpoch(fire, isUtc: true)
        : DateTime.fromMicrosecondsSinceEpoch(fire);
  }

  @override
  String describe() => 'interval($period)';
}

// =============================================================================
// ONCE
// =============================================================================

/// A single absolute instant: fire once at [at], then never again.
///
/// The other clock-driven schedules all recur. This one is what expresses a
/// **deadline** — "escalate this ticket at 09:00 on the 1st", "expire this
/// invitation in seven days" — and it is the shape a timer wait takes when a
/// multi-step process is built out of jobs rather than out of a process engine.
/// Without it, a caller needing one future instant has to abuse
/// [TomIntervalSchedule] (which will fire again) or write a subclass at the
/// call site.
///
/// It needs no scheduler support because [TomSchedule] already accommodates it:
/// `null` from [nextFireAfter] means *never again*, so the whole implementation
/// is "the instant, if we are not past it yet".
///
/// ## An instant, not a wall-clock position
///
/// [at] is an absolute moment. Its zone affects nothing — a deadline of
/// `2026-08-01T09:00Z` is the same moment whether it is compared against a UTC
/// or a local clock, and unlike the recurring schedules there is no DST
/// question to answer because there is no recurrence to shift. [nextFireAfter]
/// still returns its answer in [from]'s zone, so the value can be compared and
/// stored like any other schedule's, but that is a rendering, not a
/// reinterpretation. [describe] prints UTC for the same reason: a deadline in an
/// alert should not depend on which host formatted it.
///
/// ## Nothing to validate, including a deadline in the past
///
/// The sibling schedules reject expressions that cannot mean anything. A
/// [DateTime] always means something, *including one already behind us*: that
/// is a schedule which will never fire, and `null` is exactly how the contract
/// spells it. The schedule cannot judge otherwise without reading a clock, and
/// [nextFireAfter] must stay pure — the scheduler replays windows
/// deterministically after a restart and would get different answers from a
/// schedule that had opinions about now.
///
/// For the same reason there is deliberately no `TomOnceSchedule.after(
/// Duration)` convenience. It would have to read the clock *at construction*,
/// and job definitions are typically rebuilt at start-up — so a "fire in three
/// days" schedule would quietly push its own deadline three days further out on
/// every restart, and a process that restarted often would never fire at all.
/// Compute the instant once, persist it, and pass it here.
///
/// ## Being planned is what survives a restart
///
/// A one-shot fires late rather than not at all when the process is down over
/// its instant, because the scheduler enqueues the window as soon as it sees
/// the job — the run is then durable store state, and
/// [TomMissedWindowPolicy.skip] does not un-plan it. The case that genuinely
/// does not fire is a job **first registered after** its instant has passed:
/// first sight anchors on the present for every schedule kind, so there is no
/// window to catch up on. The scheduler raises
/// [TomJobAlertKind.neverFires] for that rather than staying quiet about it.
class TomOnceSchedule extends TomSchedule {
  /// The one instant this schedule fires at.
  final DateTime at;

  /// Creates a schedule that fires once at [at].
  const TomOnceSchedule(this.at);

  @override
  DateTime? nextFireAfter(DateTime from) {
    // Strictly after, like every other schedule: asked exactly at the instant,
    // the answer is "never again" — that window has been reached, and offering
    // it a second time would fire the deadline twice.
    if (!from.isBefore(at)) return null;
    return from.isUtc ? at.toUtc() : at.toLocal();
  }

  @override
  String describe() => 'once(${at.toUtc().toIso8601String()})';
}

// =============================================================================
// EVENT
// =============================================================================

/// A trigger fed by a source rather than a clock.
///
/// CE-JB's third trigger kind. [nextFireAfter] always answers `null` and
/// [isClockDriven] is `false`, so the scheduler never polls it; instead it
/// subscribes to [events] and enqueues one run per emitted element.
///
/// The emitted value is available to the job body as the run's payload, so an
/// event-triggered job can act on *what* happened rather than merely *that*
/// something did.
class TomEventSchedule extends TomSchedule {
  /// The source whose elements become job runs.
  final Stream<Object?> events;

  /// A label for logs and alerts, since a stream has no readable identity.
  final String sourceName;

  /// Creates an event trigger over [events].
  const TomEventSchedule(this.events, {this.sourceName = 'event'});

  @override
  bool get isClockDriven => false;

  @override
  DateTime? nextFireAfter(DateTime from) => null;

  @override
  String describe() => 'event($sourceName)';
}

// =============================================================================
// SHARED HELPERS
// =============================================================================

/// Builds a [DateTime] in the same zone as [reference].
///
/// Out-of-range components are normalised by the `DateTime` constructor (month
/// 13 becomes January of the next year, day 32 rolls into the next month),
/// which is what lets the search loops step forward by simply incrementing a
/// component instead of doing calendar arithmetic by hand.
DateTime _at(
  DateTime reference,
  int year,
  int month,
  int day, [
  int hour = 0,
  int minute = 0,
]) =>
    reference.isUtc
        ? DateTime.utc(year, month, day, hour, minute)
        : DateTime(year, month, day, hour, minute);
