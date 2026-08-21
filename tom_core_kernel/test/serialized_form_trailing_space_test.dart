import 'dart:io';

import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Every string the module serializes ends in a space, and every document that
/// states the format has to say so.
///
/// `TomTimezone.toString()` appends one, and because every zoned value renders
/// its zone through that method, the space reaches the end of every serialized
/// form the module produces. It is the one part of the format a reader cannot
/// see: it survives into stored data, it is invisible in a log line, and two
/// values that differ only by it compare unequal. A document that shows the
/// shape without it is not merely incomplete — it is the exact form that a
/// reader will write an equality check against, and the check will fail.
///
/// So the emitted bytes are the anchor. A format template is a claim about the
/// whole of the output, and wherever one appears the passage around it must
/// state the space. Both halves are needed: a behaviour test alone cannot
/// notice a document that has stopped matching it, and a keyword scan alone
/// would pass against a space that emission no longer produces.
///
/// If the space is ever removed, this guard is what says which documents have
/// to change with it.
void main() {
  setUpAll(tz_data.initializeTimeZones);

  // ===========================================================================
  // What is emitted
  // ===========================================================================
  group('the serialized form ends in a space', () {
    test('every emitter appends exactly one', () {
      for (final emitter in _emitters) {
        final rendered = emitter.render();
        expect(
          rendered,
          endsWith(' '),
          reason: '${emitter.what} does not end in the trailing space',
        );
        expect(
          rendered.trimRight(),
          isNot(endsWith(' ')),
          reason: '${emitter.what} ends in more than one space',
        );
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

    test('the space is what makes two equal values compare unequal', () {
      // Not decoration: this is the failure a reader meets when they compare a
      // stored value against a format example that omits it.
      final rendered = _emitters.last.render();
      expect(TomTimezoned.isTomTimezonedString(rendered), isTrue);
      expect(TomTimezoned.isTomTimezonedString(rendered.trimRight()), isTrue);
      expect(rendered, isNot(equals(rendered.trimRight())));
    });
  });

  // ===========================================================================
  // What is documented
  // ===========================================================================
  group('every stated format mentions the trailing space', () {
    test('no format template stands without it', () {
      expect(_silentTemplates(), isEmpty, reason: _reason);
    });

    test('the scan finds the templates it claims to check', () {
      // A scan matching nothing reports a clean tree whether or not the tree is
      // clean. The templates are the subject, so there must be some.
      expect(_templateSites(), hasLength(greaterThanOrEqualTo(8)));
    });

    test('the scan rejects a passage that omits it', () {
      const silent = ['## Heading', '', '`ISO8601_OFFSET_TIMEZONE`', ''];
      expect(_mentionsSpaceNear(silent, 2, '.md'), isFalse);

      const stated = [
        '## Heading',
        '',
        '`ISO8601_OFFSET_TIMEZONE`, ending in a trailing space.',
        '',
      ];
      expect(_mentionsSpaceNear(stated, 2, '.md'), isTrue);
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
List<String> _silentTemplates() => [
  for (final site in _scan())
    if (!site.mentionsSpace) '${site.path}:${site.line}: ${site.text.trim()}',
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
    'A format template states the whole shape of a serialized string, and '
    'every string the module produces ends in a space. A passage that gives '
    'the template without saying so describes a value that is one character '
    'short of anything the module emits — and it is the form a reader will '
    'compare stored data against.';
