import 'dart:io';

import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// No string the module serializes ends in whitespace, and no document claims
/// one does.
///
/// Every zoned value renders its zone through `TomTimezone.toString()`, so
/// whatever that method appends reaches the end of every serialized form the
/// module produces. For a long time it appended a space, which is the one part
/// of a format a reader cannot see: it travelled into stored data, into map
/// keys and into URLs, and two values differing only by it compared unequal
/// with nothing to show why.
///
/// So the emitted bytes are the anchor, and the documents are checked against
/// them. Both halves are needed: a behaviour test alone cannot notice a
/// document that has stopped matching, and a documentation scan alone would
/// pass against emission that had quietly changed.
void main() {
  setUpAll(tz_data.initializeTimeZones);

  // ===========================================================================
  // What is emitted
  // ===========================================================================
  group('the serialized form ends where the zone name ends', () {
    test('no emitter appends whitespace', () {
      for (final emitter in _emitters) {
        final rendered = emitter.render();
        expect(
          rendered,
          equals(rendered.trimRight()),
          reason: '${emitter.what} ends in whitespace',
        );
        expect(rendered, isNotEmpty, reason: '${emitter.what} renders nothing');
      }
    });

    // A table that lost its entries would pass the loop above in silence, and
    // the whole point is that it covers every way the module renders a value.
    test('the table covers every emitter the module has', () {
      expect(_emitters, hasLength(6));
      for (final emitter in _emitters) {
        expect(emitter.render(), isNotEmpty);
      }
    });

    test('a value carrying stray whitespace is rejected, not absorbed', () {
      // The reason the parse patterns anchor at the zone name rather than
      // tolerating `\s?`: a lenient reader accepts a string it will then
      // compare unequal to the one it produces, and neither is malformed, so
      // nothing reports why.
      final rendered = _emitters.last.render();
      expect(TomTimezoned.isTomTimezonedString(rendered), isTrue);
      expect(TomTimezoned.isTomTimezonedString('\$rendered '), isFalse);
    });
  });

  // ===========================================================================
  // What is documented
  // ===========================================================================
  group('no stated format claims a trailing space', () {
    test('no passage around a format template mentions one', () {
      expect(_templatesClaimingSpace(), isEmpty, reason: _reason);
    });

    test('the scan finds the templates it claims to check', () {
      // A scan matching nothing reports a clean tree whether or not the tree is
      // clean. The templates are the subject, so there must be some.
      expect(_templateSites(), hasLength(greaterThanOrEqualTo(8)));
    });

    test('the scan still recognises a passage that claims one', () {
      const clean = ['## Heading', '', '`ISO8601_OFFSET_TIMEZONE`', ''];
      expect(_mentionsSpaceNear(clean, 2, '.md'), isFalse);

      const claiming = [
        '## Heading',
        '',
        '`ISO8601_OFFSET_TIMEZONE`, ending in a trailing space.',
        '',
      ];
      expect(_mentionsSpaceNear(claiming, 2, '.md'), isTrue);
    });
  });
}

// -----------------------------------------------------------------------------
// The anchor: what the module actually emits
// -----------------------------------------------------------------------------

/// One way the module renders a value, and the call that does it.
class _Emitter {
  const _Emitter(this.what, this.render);

  final String what;
  final String Function() render;
}

TomTimezone get _tokyo => TomTimezone.fromName('Asia/Tokyo')!;

final List<_Emitter> _emitters = [
  _Emitter('TomTimezone.toString', () => TomTimezone.utc.toString()),
  _Emitter(
    'TomTimezone.toStringOn',
    () => _tokyo.toStringOn(DateTime.utc(2024, 1, 15)),
  ),
  _Emitter(
    'TomZonedDateTime.toString',
    () => TomZonedDateTime(
      year: 2024,
      month: 6,
      day: 15,
      hour: 14,
      minute: 30,
      timezone: _tokyo,
    ).toString(),
  ),
  _Emitter(
    'TomZonedDate.toString',
    () => TomZonedDate(
      year: 2024,
      month: 6,
      day: 15,
      timezone: _tokyo,
    ).toString(),
  ),
  _Emitter(
    'TomZonedTime.toString',
    () => TomZonedTime(hour: 14, minute: 30, timezone: _tokyo).toString(),
  ),
  _Emitter(
    'TomTimezoned.toString',
    () => TomTimezoned.fromDateTime(
      DateTime.utc(2024, 6, 15, 5, 30),
      _tokyo,
    ).toString(),
  ),
];

// -----------------------------------------------------------------------------
// The scan: what the documents state
// -----------------------------------------------------------------------------

/// Tokens that stand for the complete shape of a serialized string.
///
/// Each is a claim that the output looks like *this* — so each is a place the
/// missing final character misleads.
const List<String> _formatTemplates = [
  'ISO8601_OFFSET_TIMEZONE',
  'ISO8601_UTC_OFFSET_TIMEZONE',
  '{offset}_{timezone}',
];

/// The files that state the format to a reader.
const List<String> _documents = [
  'doc/timezoned/timezoned.md',
  'doc/api_reference/api_summary_timezoned.md',
  'lib/src/tombase/timezoned/timezones.dart',
];

/// Ways a passage can name the space. Alternatives, so the guard constrains
/// what is said and not the exact wording.
const List<String> _spacePhrases = [
  'trailing space',
  'ends in a space',
  'final space',
];

/// `'<path>:<line>'` for every template occurrence.
List<String> _templateSites() => [
  for (final site in _scan()) '${site.path}:${site.line}',
];

/// Template occurrences whose passage never names the space.
List<String> _templatesClaimingSpace() => [
  for (final site in _scan())
    if (site.mentionsSpace) '${site.path}:${site.line}: ${site.text.trim()}',
];

class _Site {
  _Site(this.path, this.line, this.text, this.mentionsSpace);

  final String path;
  final int line;
  final String text;
  final bool mentionsSpace;
}

List<_Site> _scan() {
  final sites = <_Site>[];

  for (final path in _documents) {
    final file = File(path);
    if (!file.existsSync()) continue;

    final lines = file.readAsLinesSync();
    final extension = path.endsWith('.md') ? '.md' : '.dart';

    for (var i = 0; i < lines.length; i++) {
      if (!_formatTemplates.any(lines[i].contains)) continue;
      sites.add(
        _Site(path, i + 1, lines[i], _mentionsSpaceNear(lines, i, extension)),
      );
    }
  }

  return sites;
}

/// Whether the passage containing [index] names the trailing space.
///
/// A reader meets the template inside a passage, not on its own, so that is
/// the unit: a markdown section between headings, or the dartdoc run attached
/// to one member. Anything wider lets a mention somewhere else in the file
/// cover a template that says nothing.
bool _mentionsSpaceNear(List<String> lines, int index, String extension) {
  final (start, end) = extension == '.md'
      ? _markdownSection(lines, index)
      : _dartdocRun(lines, index);

  final passage = lines
      .getRange(start, end)
      .join(' ')
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');

  return _spacePhrases.any(passage.contains);
}

/// The lines from the nearest heading above [index] to the next one.
(int, int) _markdownSection(List<String> lines, int index) {
  final heading = RegExp(r'^#{1,6}\s');

  var start = index;
  while (start > 0 && !heading.hasMatch(lines[start])) {
    start--;
  }

  var end = index + 1;
  while (end < lines.length && !heading.hasMatch(lines[end])) {
    end++;
  }

  return (start, end);
}

/// The unbroken run of `///` lines containing [index].
(int, int) _dartdocRun(List<String> lines, int index) {
  bool isDoc(int i) => lines[i].trimLeft().startsWith('///');
  if (!isDoc(index)) return (index, index + 1);

  var start = index;
  while (start > 0 && isDoc(start - 1)) {
    start--;
  }

  var end = index + 1;
  while (end < lines.length && isDoc(end)) {
    end++;
  }

  return (start, end);
}

const _reason =
    'A format template states the whole shape of a serialized string, and no '
    'string the module produces ends in whitespace. A passage that still '
    'claims a trailing space describes a value one character longer than '
    'anything the module emits — and it is the form a reader will compare '
    'stored data against.';
