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
  // The roster parse itself
  // ===========================================================================
  group('the roster parse reads member entries, not prose', () {
    test('every line of the real roster is a member entry', () {
      expect(
        _parseRoster(_leadIn(_sharedHeading)).notEntries,
        isEmpty,
        reason:
            'A line in the shared block is neither a list of members nor a '
            '// remark. Put prose in a remark or outside the fence; the '
            'roster is read as a list of members.',
      );
    });

    test('remarks contribute no names', () {
      final roster = _parseRoster(const [
        '```text',
        '// Common accessors (return UTC values)',
        '  year, month',
        '  timezone          // The associated TomTimezone',
        '  toString()        // Serialize to string',
        '```',
      ]);
      expect(roster.names, {'year', 'month', 'timezone', 'toString'});
      expect(roster.notEntries, isEmpty);
    });

    test('a prose line is reported, not read as names', () {
      final roster = _parseRoster(const [
        '```text',
        '  year',
        '  Conversion lives on the subclasses, with local values.',
        '```',
      ]);
      expect(roster.names, {'year'});
      expect(roster.notEntries, hasLength(1));
    });

    test('a stale entry is read as a name, so the comparison catches it', () {
      final roster = _parseRoster(const [
        '```text',
        '  year, month',
        '  convertToTzSameInstant(zone)   // not on the base class',
        '```',
      ]);
      expect(roster.names, contains('convertToTzSameInstant'));
      expect(roster.names.difference(_sharedMembers.keys.toSet()), {
        'convertToTzSameInstant',
      });
    });

    test('only the first fence is the roster', () {
      final roster = _parseRoster(const [
        '```text',
        '  year',
        '```',
        'Prose between the fences.',
        '```dart',
        'final moved = value.convertToTzSameInstant(zone);',
        '```',
      ]);
      expect(roster.names, {'year'});
      expect(roster.notEntries, isEmpty);
    });
  });

  // ===========================================================================
  // What belongs to the subclasses instead
  // ===========================================================================
  group('per-subclass members are documented per subclass', () {
    test('conversion is not offered as a shared member', () {
      expect(_sharedBlockNames(), isNot(contains('convertToTzSameInstant')));
      expect(_sharedMembers.keys, isNot(contains('convertToTzSameInstant')));
    });

    test('each subclass section shows every conversion its type has', () {
      for (final entry in _conversionsByType.entries) {
        final body = _section('### ${entry.key}').join('\n');
        for (final method in entry.value) {
          expect(
            body,
            contains(method),
            reason:
                '${entry.key} declares $method, and the shared block does not '
                'mention it, so this section is the only place a reader can '
                'find it.',
          );
        }
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

  // ===========================================================================
  // Why conversion stays per-subclass
  // ===========================================================================
  //
  // The reason is not that a shared declaration is impossible — Dart permits an
  // override to narrow its return type, so a base `convertToTzSameInstant` that
  // each subclass narrowed would compile. It is that the three types do not
  // offer the same set, and the one method they share is the wrong default for
  // two of them. Hoisting it would install that default on any value whose kind
  // the caller has not established, and it would compile, so nothing would say
  // so.
  //
  // That argument only holds while the sets really do differ, so this is where
  // it is checked rather than asserted in prose.
  group('the conversion sets differ by type', () {
    final zone = TomTimezone.fromName('America/New_York')!;

    test('each type has the conversions its kind admits', () {
      // Statically typed on purpose: a method that leaves its class takes this
      // file's compilation with it rather than failing at run time.
      expect(_zonedDate().convertToTzSameInstant(zone), isA<TomZonedDate>());
      expect(_zonedDate().convertToTzSameDate(zone), isA<TomZonedDate>());
      expect(_zonedTime().convertToTzSameInstant(zone), isA<TomZonedTime>());
      expect(_zonedTime().convertToTzSameTime(zone), isA<TomZonedTime>());
      expect(
        _zonedDateTime().convertToTzSameInstant(zone),
        isA<TomZonedDateTime>(),
      );
    });

    test('and none of the ones it does not', () {
      // Through `dynamic`, because "this member does not exist" is not
      // something a static call can express: the guard has to survive
      // compilation to be able to fail.
      expect(
        () => (_zonedDate() as dynamic).convertToTzSameTime(zone),
        throwsNoSuchMethodError,
        reason: 'a date has no clock reading to re-anchor',
      );
      expect(
        () => (_zonedTime() as dynamic).convertToTzSameDate(zone),
        throwsNoSuchMethodError,
        reason: 'a time has no calendar day to re-anchor',
      );
      expect(
        () => (_zonedDateTime() as dynamic).convertToTzSameDate(zone),
        throwsNoSuchMethodError,
        reason: 'a datetime already names an instant; nothing is left to move',
      );
      expect(
        () => (_zonedDateTime() as dynamic).convertToTzSameTime(zone),
        throwsNoSuchMethodError,
      );
    });

    test('the base class has none of them', () {
      // This is the decision itself. If a conversion is ever hoisted onto
      // TomTimezoned, this is what says so — and the reasoning above, in this
      // file and in the module documents, is what has to be revisited.
      final base = _baseInstance();
      expect(
        () => (base as dynamic).convertToTzSameInstant(zone),
        throwsNoSuchMethodError,
      );
      expect(
        () => (base as dynamic).convertToTzSameDate(zone),
        throwsNoSuchMethodError,
      );
      expect(
        () => (base as dynamic).convertToTzSameTime(zone),
        throwsNoSuchMethodError,
      );
    });

    test('the document states the same sets', () {
      expect(
        _documentedConversions(),
        _conversionsByType,
        reason:
            'The conversion table under $_sharedHeading is the reader\'s map '
            'of which conversion belongs to which type, and it is the '
            'justification for the base class having none. A table that no '
            'longer matches the code argues for a design the code does not '
            'have.',
      );
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

/// The headings whose types declare their own conversions.
const List<String> _subclassHeadings = [
  '### TomZonedDateTime',
  '### TomZonedDate',
  '### TomZonedTime',
];

/// Which conversion each type offers.
///
/// The sets differ, and that difference is the whole reason conversion is not
/// hoisted onto [TomTimezoned]: the only method all three share preserves the
/// instant, which is the wrong answer for a date and for a time.
const Map<String, List<String>> _conversionsByType = {
  'TomZonedDate': ['convertToTzSameInstant', 'convertToTzSameDate'],
  'TomZonedTime': ['convertToTzSameInstant', 'convertToTzSameTime'],
  'TomZonedDateTime': ['convertToTzSameInstant'],
};

TomZonedDate _zonedDate() => TomZonedDate(
  year: 2024,
  month: 6,
  day: 15,
  timezone: TomTimezone.fromName('Asia/Tokyo')!,
);

TomZonedTime _zonedTime() => TomZonedTime(
  hour: 9,
  minute: 30,
  timezone: TomTimezone.fromName('Asia/Tokyo')!,
);

TomZonedDateTime _zonedDateTime() => TomZonedDateTime(
  year: 2024,
  month: 6,
  day: 15,
  hour: 14,
  minute: 30,
  timezone: TomTimezone.fromName('Asia/Tokyo')!,
);

/// The conversion table in the document's shared lead-in, read back.
///
/// One row per type, naming the conversions it offers in backticks. Reading it
/// rather than trusting it is what keeps the argument for the base class having
/// none tied to the code that makes the argument true.
Map<String, List<String>> _documentedConversions() {
  final rows = <String, List<String>>{};
  final name = RegExp(r'\[(Tom\w+)\]');
  final method = RegExp(r'`(convertToTz\w+)`');

  for (final line in _leadIn(_sharedHeading)) {
    if (!line.startsWith('|')) continue;
    final cells = line.split('|');
    if (cells.length < 3) continue;
    final type = name.firstMatch(cells[1]);
    if (type == null) continue;
    final methods = method
        .allMatches(cells[2])
        .map((m) => m.group(1)!)
        .toList();
    if (methods.isEmpty) continue;
    rows[type.group(1)!] = methods;
  }

  return rows;
}

/// The member names listed in the shared block.
///
/// The block is the *first* fenced code under the heading — the roster itself.
/// Anything fenced after it is illustration, and illustration names locals and
/// calls per-subclass members, so reading it too would make the roster look
/// like whatever the examples happen to mention.
Set<String> _sharedBlockNames() => _parseRoster(_leadIn(_sharedHeading)).names;

/// What [_parseRoster] found: the member names, and the roster lines that were
/// not member entries at all.
typedef _Roster = ({Set<String> names, List<String> notEntries});

/// Parses the first fenced block in [lines] as a member roster.
///
/// A roster line is a comma-separated list of member entries — a bare name or
/// a call such as `toString()` — optionally followed by a `//` remark. The
/// parse drops the remark and the parameter lists (a signature names its
/// argument too, and an argument is not a member) and then requires what is
/// left to be exactly that list.
///
/// A line that is not is reported in `notEntries` rather than mined for
/// identifiers. Mining it is what turns a sentence into a dozen "members" —
/// `the`, `with`, `values` — each of which the comparison against the base
/// class then reports as a stale entry, so a real stale member becomes
/// indistinguishable from the document's grammar.
_Roster _parseRoster(List<String> lines) {
  final names = <String>{};
  final notEntries = <String>[];
  final entryList = RegExp(r'^[a-z]\w*(\s*,\s*[a-z]\w*)*\s*,?$');
  var inFence = false;

  for (final line in lines) {
    if (line.startsWith('```')) {
      if (inFence) break;
      inFence = true;
      continue;
    }
    if (!inFence) continue;

    final code = line
        .split('//')
        .first
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .trim();
    if (code.isEmpty) continue;
    if (!entryList.hasMatch(code)) {
      notEntries.add(line);
      continue;
    }
    for (final name in code.split(',')) {
      if (name.trim().isNotEmpty) names.add(name.trim());
    }
  }

  return (names: names, notEntries: notEntries);
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
