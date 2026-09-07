import 'dart:io';

import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// "All types share these features" is a promise about the base class, and the
/// only way to keep it honest is to state it in code that would not compile if
/// it were false.
///
/// A member listed there is one a reader will reach for through a
/// [TomTimezoned] variable — the type they hold after `now()` or
/// `parseFromString`, both of which return the base class itself rather than
/// any subclass. If the list names something only the subclasses declare, the
/// reader's code does not fail at that line with a clear message; it fails to
/// compile, and the document is what sent them there.
///
/// So the list below is the anchor, and it is not a list of strings: each entry
/// carries a closure that actually reads the member off a base instance. A
/// member that leaves [TomTimezoned] takes this file's compilation with it, and
/// one that is merely renamed cannot be papered over by editing a literal. The
/// scan then holds the document to exactly that set — in both directions, so
/// neither a stale entry nor a missing one survives.
///
/// The subclass half matters just as much. A member that is genuinely
/// per-subclass has to be documented under the subclasses, or removing it from
/// the shared block would simply lose it.
void main() {
  setUpAll(tz_data.initializeTimeZones);

  // ===========================================================================
  // What the base class actually offers
  // ===========================================================================
  group('the shared members are shared', () {
    test('every one of them can be read off a base instance', () {
      final value = _baseInstance();
      for (final entry in _sharedMembers.entries) {
        expect(
          entry.value(value),
          isNotNull,
          reason: '${entry.key} is not readable on a plain TomTimezoned',
        );
      }
    });

    // The map is the anchor for both directions of the comparison below, so an
    // emptied map would let the document say anything at all.
    test('the anchor names a full set of members', () {
      expect(_sharedMembers, hasLength(greaterThanOrEqualTo(20)));
    });

    test('a value from now() or parseFromString is that base class', () {
      // Why the shared block has to be exact: these two entry points hand back
      // the base class, so its member set is the whole of what such a value
      // can do.
      expect(TomTimezoned.now(), isNot(isA<TomZonedDateTime>()));
      expect(TomTimezoned.now(), isNot(isA<TomZonedDate>()));
      expect(TomTimezoned.now(), isNot(isA<TomZonedTime>()));

      final parsed = TomTimezoned.parseFromString(
        '2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo',
      );
      expect(parsed, isNot(isA<TomZonedDateTime>()));
    });
  });

  // ===========================================================================
  // What the document claims
  // ===========================================================================
  group('the shared block matches the base class', () {
    test('it claims nothing the base class does not have', () {
      expect(
        _sharedBlockNames().difference(_sharedMembers.keys.toSet()),
        isEmpty,
        reason:
            'The shared block lists a member that a plain TomTimezoned does '
            'not have. A reader holding the value that now() and '
            'parseFromString return cannot call it, and the failure is a '
            'compile error rather than anything the document warned about.',
      );
    });

    test('it omits nothing the base class does have', () {
      expect(
        _sharedMembers.keys.toSet().difference(_sharedBlockNames()),
        isEmpty,
        reason:
            'The base class has a member the shared block never mentions, so '
            'a reader has no way to learn of it from the type overview.',
      );
    });

    // Both comparisons above are set differences, which are empty against an
    // empty set. The parse has to have found something.
    test('the scan finds the block it claims to check', () {
      expect(_sharedBlockNames(), hasLength(greaterThanOrEqualTo(20)));
    });
  });

  // ===========================================================================
  // What belongs to the subclasses instead
  // ===========================================================================
  group('per-subclass members are documented per subclass', () {
    test('conversion is not offered as a shared member', () {
      // The narrowed return type is why there is no shared declaration to
      // inherit: each subclass returns its own type, so the base has none.
      expect(_sharedBlockNames(), isNot(contains('convertToTzSameInstant')));
      expect(_sharedMembers.keys, isNot(contains('convertToTzSameInstant')));
    });

    test('each subclass section shows it', () {
      for (final heading in _subclassHeadings) {
        expect(
          _section(heading).join('\n'),
          contains('convertToTzSameInstant'),
          reason:
              '$heading declares convertToTzSameInstant, and the shared block no '
              'longer mentions it, so this section is the only place a reader '
              'can find it.',
        );
      }
    });

    test('the scan finds the sections it claims to check', () {
      for (final heading in _subclassHeadings) {
        expect(
          _section(heading),
          hasLength(greaterThan(1)),
          reason: 'no section body found for $heading',
        );
      }
    });
  });
}

// -----------------------------------------------------------------------------
// The anchor: members read off a real base instance
// -----------------------------------------------------------------------------

TomTimezoned _baseInstance() => TomTimezoned(
  year: 2024,
  month: 6,
  day: 15,
  hour: 14,
  minute: 30,
  second: 5,
  millisecond: 250,
  microsecond: 125,
  timezone: TomTimezone.fromName('Asia/Tokyo')!,
);

/// Every member the shared block is allowed to name, paired with the code that
/// reads it.
///
/// The closures are the point. A plain list of names would still compile after
/// a member was removed from [TomTimezoned]; these do not.
final Map<String, Object? Function(TomTimezoned)> _sharedMembers = {
  // UTC components, inherited from DateTime.
  'year': (v) => v.year,
  'month': (v) => v.month,
  'day': (v) => v.day,
  'hour': (v) => v.hour,
  'minute': (v) => v.minute,
  'second': (v) => v.second,
  'millisecond': (v) => v.millisecond,
  'microsecond': (v) => v.microsecond,
  'weekday': (v) => v.weekday,

  // The same components read in the associated timezone.
  'localYear': (v) => v.localYear,
  'localMonth': (v) => v.localMonth,
  'localDay': (v) => v.localDay,
  'localHour': (v) => v.localHour,
  'localMinute': (v) => v.localMinute,
  'localSecond': (v) => v.localSecond,
  'localMillisecond': (v) => v.localMillisecond,
  'localMicrosecond': (v) => v.localMicrosecond,
  'localWeekday': (v) => v.localWeekday,

  // Declared on TomTimezoned itself.
  'timezone': (v) => v.timezone,
  'getSerializationPrefix': (v) => v.getSerializationPrefix(),
  'toDateTime': (v) => v.toDateTime(),
  'toString': (v) => v.toString(),
};

// -----------------------------------------------------------------------------
// The scan: what the type overview states
// -----------------------------------------------------------------------------

const String _document = 'doc/timezoned/timezoned.md';

/// The heading that introduces the shared-member block.
const String _sharedHeading = '## TomTimezoned Types';

/// The headings whose types declare their own `convertToTzSameInstant`.
const List<String> _subclassHeadings = [
  '### TomZonedDateTime',
  '### TomZonedDate',
  '### TomZonedTime',
];

/// The member names listed in the shared block.
///
/// The block is the *first* fenced code under the heading — the roster itself.
/// Anything fenced after it is illustration, and illustration names locals and
/// calls per-subclass members, so reading it too would make the roster look
/// like whatever the examples happen to mention.
///
/// Inside the roster the lines are prose-shaped — bare identifiers, call syntax
/// and `//` remarks mixed together — so the parse drops comments and parameter
/// lists, then takes what identifiers remain. Dropping the parameters matters:
/// a signature names its argument too, and an argument is not a member.
Set<String> _sharedBlockNames() {
  final names = <String>{};
  var inFence = false;

  for (final line in _leadIn(_sharedHeading)) {
    if (line.startsWith('```')) {
      if (inFence) break;
      inFence = true;
      continue;
    }
    if (!inFence) continue;

    final code = line.split('//').first.replaceAll(RegExp(r'\([^)]*\)'), '');

    for (final match in RegExp(r'\b[a-z]\w*\b').allMatches(code)) {
      names.add(match.group(0)!);
    }
  }

  return names;
}

List<String> _lines() => File(_document).readAsLinesSync();

/// The lines from [heading] up to the next heading of *any* level.
///
/// This is the passage a reader meets before the document starts breaking the
/// topic down — for `## TomTimezoned Types`, everything said about all three
/// types before the first type gets its own section.
List<String> _leadIn(String heading) => _from(heading, RegExp(r'^#{1,6}\s'));

/// The lines from [heading] up to the next heading of the same level or higher,
/// so a section keeps the subsections nested underneath it.
List<String> _section(String heading) =>
    _from(heading, RegExp('^#{1,${heading.indexOf(' ')}}\\s'));

List<String> _from(String heading, RegExp stop) {
  final lines = _lines();
  final start = lines.indexOf(heading);
  if (start < 0) return const [];

  var end = start + 1;
  while (end < lines.length && !stop.hasMatch(lines[end])) {
    end++;
  }

  return lines.sublist(start, end);
}
