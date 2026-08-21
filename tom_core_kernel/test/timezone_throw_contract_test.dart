/// The guard that keeps the module's documented failures equal to the ones it
/// has — both *why* it refuses and *what the caller catches*.
///
/// ## Why `findTimezone` throws
///
/// `TomTimezone.findTimezone` throws for two unrelated reasons: the name is not
/// in the database, or the name is there but its current offset is not the one
/// the caller supplied. One `throw` serves both, which is why they are easy to
/// describe as one.
///
/// The unknown-name case is the one that surprises, because the neighbouring
/// lookup does the opposite: `fromName('Mars/Olympus')` returns `null`, while
/// `findTimezone('Mars/Olympus', null)` throws on the same name. A reader who
/// has met `fromName` first will expect `null`, and documentation that names
/// only the offset mismatch confirms them in that expectation.
///
/// Both halves of the contract are checked from one table. Each entry carries
/// the call that provokes the failure and the words the documentation must use
/// to warn about it, so a mode cannot be listed without being executed, and a
/// mode that is executed cannot go undescribed. That link is the point: a
/// keyword scan on its own would pass against wording that no longer matches
/// the code, and a behaviour test on its own is what the module already had
/// when the description drifted.
///
/// ## Which type each refusal surfaces as
///
/// The module refuses in three shapes, and which one a caller meets depends on
/// the entry point rather than on the mistake: `fromName` returns `null`,
/// `findTimezone` throws `TomTimezoneException`, and `parseFromString` throws
/// `FormatException`. "A zone that is not in the database" reaches all three,
/// so the trigger does not reveal the shape and a document can attribute one to
/// the wrong entry point while every word in it looks right. The module readme
/// did: it credited `TomTimezoneException` with "unknown zones / parse
/// failures", of which the first was half true and the second belonged to
/// `FormatException`.
///
/// The rule that catches it is that **every exception type a passage names must
/// belong to something that passage mentions**. A denial — "throws
/// `FormatException` and never `TomTimezoneException`" — is not an attribution
/// and is struck out before judging, because a sentence that names the type it
/// is *not* is the one most worth writing here.
///
/// The web case is left out of the table on purpose. A first access before
/// `await tomSetupTimezones()` throws `StateError`, but only on the browser,
/// and this suite runs on the VM. A mode that cannot be provoked here would sit
/// in the table as an unexecuted claim, which is exactly what the table exists
/// to prevent; `timezoned_platform_selection_test.dart` holds the platform
/// documentation instead.
///
/// ## Where the contracts are stated
///
/// Four documents are held to them — the method's own dartdoc, the module
/// readme, the narrative guide, and the API mirror. In the markdown files it is
/// not the file as a whole that must name both modes but each passage that
/// raises the subject: the omission being guarded against was a single trailing
/// comment that said `Throws if mismatch`, and a file-wide search would have
/// found the missing half somewhere else and reported nothing.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// The contract
// =============================================================================

/// One way `findTimezone` fails, and how the documentation must say so.
class _FailureMode {
  const _FailureMode({
    required this.what,
    required this.provoke,
    required this.named,
  });

  /// How the mode reads in a failure message.
  final String what;

  /// A call that must throw [TomTimezoneException] for this reason.
  final void Function() provoke;

  /// Ways of naming the mode, any one of which will do.
  ///
  /// Alternatives rather than one fixed phrase, so the documentation can be
  /// reworded without the guard turning into a lock on its own prose. What is
  /// pinned is that the mode is named at all.
  final Set<String> named;
}

/// The reasons `findTimezone` throws.
///
/// `'Mars/Olympus'` is not a place; the database holding it would be a larger
/// surprise than the one under test. The offset is left null in that entry to
/// pin the case that reads as benign — an unknown name throws on its own, with
/// no offset supplied to disagree with.
final List<_FailureMode> _failureModes = [
  _FailureMode(
    what: 'a name the database does not hold',
    provoke: () => TomTimezone.findTimezone('Mars/Olympus', null),
    named: {'not found', 'not in the database', 'unknown', 'no such'},
  ),
  _FailureMode(
    what: 'an offset that disagrees with the named zone',
    provoke: () => TomTimezone.findTimezone('UTC', 60),
    named: {'does not match', "doesn't match", 'differs', 'mismatch'},
  ),
];

/// One way the module refuses, and the shape the caller meets it in.
///
/// [surfaces] is the exception type, or `null` where the refusal is a `null`
/// return rather than a throw. That case belongs in the same table as the
/// throws: the mistake the documentation makes is choosing between them, so a
/// table holding only the throws could not describe the choice.
class _Refusal {
  const _Refusal({
    required this.what,
    required this.provoke,
    required this.surfaces,
    required this.surfaceNamed,
    required this.triggeredBy,
  });

  /// How the refusal reads in a failure message.
  final String what;

  /// A call that must produce [surfaces].
  final Object? Function() provoke;

  /// The exception type raised, or `null` for a `null` return.
  final Type? surfaces;

  /// How a document names the shape, lowercase.
  final String surfaceNamed;

  /// Lowercase phrases that put a passage on this refusal's subject.
  ///
  /// The parse entries carry `parse failure` as well as the method name because
  /// that is how the defective readme referred to parsing — naming the outcome
  /// without naming the call. A guard keyed only on `parseFromString` would
  /// have read straight past it.
  final Set<String> triggeredBy;
}

/// Every refusal the module can be provoked into on this platform.
///
/// The two parse entries share a surface and a trigger set but not a cause, and
/// both are listed because the readme's claim was about the *category*: if only
/// the malformed-string case were executed, "an unknown zone is a parse
/// failure" — the half that reads like a `TomTimezoneException` and is not one
/// — would go unchecked.
final List<_Refusal> _refusals = [
  _Refusal(
    what: 'a name the lenient lookup cannot find',
    provoke: () => TomTimezone.fromName('Mars/Olympus'),
    surfaces: null,
    surfaceNamed: 'null',
    triggeredBy: {'fromname'},
  ),
  _Refusal(
    what: 'a name the strict lookup cannot find',
    provoke: () => TomTimezone.findTimezone('Mars/Olympus', null),
    surfaces: TomTimezoneException,
    surfaceNamed: 'tomtimezoneexception',
    triggeredBy: {'findtimezone'},
  ),
  _Refusal(
    what: 'a string that is not in the serialized form',
    provoke: () => TomZonedDateTime.parseFromString('invalid'),
    surfaces: FormatException,
    surfaceNamed: 'formatexception',
    triggeredBy: {'parsefromstring', 'parse failure', 'parsing'},
  ),
  _Refusal(
    what: 'a serialized string naming a zone the database does not hold',
    provoke: () => TomZonedDateTime.parseFromString(
      '@X@2024-06-15T05:30:00.000Z_+09:00_Mars/Olympus',
    ),
    surfaces: FormatException,
    surfaceNamed: 'formatexception',
    triggeredBy: {'parsefromstring', 'parse failure', 'parsing'},
  ),
];

// =============================================================================
// Where the contract is stated
// =============================================================================

/// The module source, relative to the package root the test runs from.
const String _sourcePath = 'lib/src/tombase/timezoned/timezones.dart';

/// The module readme.
const String _readmePath = 'lib/src/tombase/timezoned/readme.md';

/// The narrative guide.
const String _guidePath = 'doc/timezoned/timezoned.md';

/// The API mirror.
const String _apiPath = 'doc/api_reference/api_summary_timezoned.md';

/// The method whose contract this guards.
const String _method = 'findTimezone';

/// Words that mark a passage as describing a failure rather than a result.
const Set<String> _throwWords = {'throw', 'thrown', 'throws', 'exception'};

/// [text] as the prose reads rather than as the file stores it.
///
/// Line wrapping is a property of the file, not of the sentence, so a phrase
/// broken across two lines still says what it says. Folding the whitespace
/// before matching keeps the guard from turning into a rule about where a
/// paragraph may be wrapped.
String _asRead(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// [text] with the mentions of [name] that it explicitly denies struck out.
///
/// A document corrects a misconception by naming the type it is *not* —
/// "throws `FormatException` and never `TomTimezoneException`". Counting that
/// as an attribution would forbid the one sentence most worth writing about
/// this module, so a denied mention is removed before the passage is judged.
String _withoutDenials(String text, String name) =>
    text.replaceAll(RegExp('(?:not|never|rather than) +`?$name`?'), '');

void main() {
  group('findTimezone throws for both documented reasons', () {
    test('every listed mode actually throws', () {
      // The anchor for everything below. If a mode stops throwing, the scans
      // are checking the documentation of a failure that no longer happens.
      for (final mode in _failureModes) {
        expect(
          mode.provoke,
          throwsA(isA<TomTimezoneException>()),
          reason:
              'findTimezone no longer throws for ${mode.what}. If that is '
              'deliberate, drop the entry from _failureModes and remove the '
              'warning from the four documents — a documented failure that '
              'cannot occur sends a reader hunting for something not there.',
        );
      }
    });

    test('an unknown name throws rather than returning null', () {
      // Stated separately from the table because the contrast is the whole
      // reason the mode is easy to miss.
      expect(TomTimezone.fromName('Mars/Olympus'), isNull);
      expect(
        () => TomTimezone.findTimezone('Mars/Olympus', null),
        throwsA(isA<TomTimezoneException>()),
        reason:
            'fromName returns null for an unknown name and findTimezone throws '
            'for it. Callers pick between the two on that difference, so it is '
            'the behaviour, not an implementation detail.',
      );
    });
  });

  group('the documentation names both reasons', () {
    test('the dartdoc describes every mode', () {
      final dartdoc = _asRead(_dartdocOf(_method));

      expect(
        dartdoc,
        isNotEmpty,
        reason:
            'No doc comment found above `$_method` in $_sourcePath. The '
            'comparison below is meaningless without it — fix the reader '
            'rather than deleting the check.',
      );

      for (final mode in _failureModes) {
        expect(
          mode.named.any(dartdoc.contains),
          isTrue,
          reason:
              'The dartdoc of `$_method` in $_sourcePath does not mention '
              '${mode.what}. Name it in one of these ways: '
              '${mode.named.join(', ')}.',
        );
      }
    });

    for (final path in [_readmePath, _guidePath, _apiPath]) {
      test('every passage in $path that raises the subject names both', () {
        final passages = _throwPassages(path, {_method.toLowerCase()});

        expect(
          passages,
          isNotEmpty,
          reason:
              'No passage in $path mentions `$_method` alongside a word from '
              '$_throwWords. Either the document stopped describing the '
              'failure, or the scan no longer finds it; both need looking at, '
              'because this test passes vacuously as it stands.',
        );

        final narrow = <String>[];
        for (final passage in passages) {
          final text = _asRead(passage.text);
          final missing = _failureModes
              .where((m) => !m.named.any(text.contains))
              .map((m) => m.what);
          if (missing.isEmpty) continue;
          narrow.add('$path:${passage.line} omits ${missing.join(' and ')}');
        }

        expect(
          narrow,
          isEmpty,
          reason:
              'These passages describe `$_method` as throwing but name only '
              'some of the reasons it does: ${narrow.join('; ')}. A passage '
              'that lists one of two triggers reads as the complete set.',
        );
      });
    }
  });

  group('each refusal surfaces as the type the readme credits it with', () {
    test('every listed refusal behaves as the table says', () {
      // The anchor again: the scan below is about attribution, and an
      // attribution can only be right or wrong against a behaviour that
      // happens.
      for (final refusal in _refusals) {
        if (refusal.surfaces == null) {
          expect(
            refusal.provoke(),
            isNull,
            reason:
                '${refusal.what} no longer returns null. The readme tells '
                'callers to choose between the lookups on exactly this, so the '
                'advice is wrong the moment the behaviour is.',
          );
          continue;
        }
        expect(
          refusal.provoke,
          throwsA(predicate((e) => e.runtimeType == refusal.surfaces)),
          reason:
              '${refusal.what} no longer surfaces as ${refusal.surfaces}. The '
              'exact type is the subject here, not merely that something was '
              'thrown: a caller writes `on ${refusal.surfaces}` and a subtype '
              'or a neighbour would walk straight past it.',
        );
      }
    });

    test('the readme describes every refusal', () {
      // Non-vacuity for the scan below, which can only fault a passage it
      // finds. A refusal nobody wrote about cannot be misattributed, and is
      // also not documented.
      final undescribed = <String>[];
      for (final refusal in _refusals) {
        final passages = _throwPassages(_readmePath, refusal.triggeredBy);
        final described = passages.any(
          (p) => _asRead(p.text).contains(refusal.surfaceNamed),
        );
        if (!described) undescribed.add(refusal.what);
      }

      expect(
        undescribed,
        isEmpty,
        reason:
            'No passage of $_readmePath puts these refusals next to what they '
            'surface as: ${undescribed.join('; ')}. Each is a way the module '
            'says no, and which of the three shapes it takes is the thing a '
            'caller cannot guess from the mistake they made.',
      );
    });

    test('every exception the readme names belongs to something it mentions', () {
      // The defect itself. The old Key types row read "Thrown on unknown zones
      // / parse failures" against `TomTimezoneException` — a passage naming a
      // type beside a trigger that raises a different one, with nothing in it
      // that the named type does belong to.
      final surfaces = {for (final r in _refusals) r.surfaceNamed};
      final misattributed = <String>[];

      for (final surface in surfaces) {
        final owners = _refusals
            .where((r) => r.surfaceNamed == surface)
            .expand((r) => r.triggeredBy)
            .toSet();
        final others = _refusals
            .where((r) => r.surfaceNamed != surface)
            .expand((r) => r.triggeredBy)
            .toSet()
            .difference(owners);

        for (final passage in _throwPassages(_readmePath, others)) {
          final text = _withoutDenials(_asRead(passage.text), surface);
          if (!text.contains(surface)) continue;
          if (owners.any(text.contains)) continue;
          misattributed.add(
            '$_readmePath:${passage.line} names `$surface` while writing about '
            '${others.where(text.contains).join(', ')}',
          );
        }
      }

      expect(
        misattributed,
        isEmpty,
        reason:
            'These passages credit a type to an entry point that does not '
            'raise it: ${misattributed.join('; ')}. Name the call the type '
            'comes from in the same passage, or say plainly that it is *not* '
            'the type — "throws `FormatException` and never '
            '`TomTimezoneException`" reads as the denial it is.',
      );
    });
  });
}

// =============================================================================
// Reading the documents
// =============================================================================

/// The doc comment attached to [member], with the `///` markers stripped.
///
/// Found by walking back from the declaration over the unbroken run of `///`
/// lines above it, which is what attaches a doc comment to a member in the
/// first place.
String _dartdocOf(String member) {
  final lines = File(_sourcePath).readAsLinesSync();
  final declaration = lines.indexWhere(
    (l) => l.contains(' $member(') && !l.trimLeft().startsWith('///'),
  );
  if (declaration < 0) return '';

  final comment = <String>[];
  for (var i = declaration - 1; i >= 0; i--) {
    final line = lines[i].trimLeft();
    if (!line.startsWith('///')) break;
    comment.add(line.replaceFirst(RegExp(r'^/// ?'), ''));
  }

  return comment.reversed.join('\n');
}

/// A run of markdown that mentions the method and says it can fail.
class _Passage {
  const _Passage(this.line, this.text);

  /// One-based line of the mention, so a failure points at the source.
  final int line;

  /// The surrounding text the mention is read in.
  final String text;
}

/// Whether [line] is a claim that stands on its own.
///
/// A trailing comment states a complete claim about the call it sits on —
/// `findTimezone(…); // Throws if mismatch` says what that call does, and
/// nothing else may be assumed to complete it. A table row is the same shape:
/// one row, one subject, one description. Reading either with its block would
/// let an unrelated neighbour supply a missing half — a line above about
/// `fromName` returning `null` for a name that is *not found* covers the words
/// while saying nothing about `findTimezone`.
///
/// Everything else is prose, and prose is read with its paragraph. Where a
/// sentence wraps is a property of the file, so a claim split across two lines
/// is still one claim; judging the first line alone would make the guard a rule
/// about line breaks.
bool _standsAlone(String line) {
  final trimmed = line.trim();
  if (trimmed.startsWith('|') && trimmed.endsWith('|')) return true;
  return trimmed.contains('//');
}

/// The passages of [path] that mention any of [mentions] and describe a failure.
///
/// A self-contained line — see [_standsAlone] — is read alone when it carries
/// its own warning; anything else is read with the run of markdown around it,
/// which for the `try` in an example is exactly right, its warning being the
/// sentence that introduces the block.
///
/// Passages carrying no word from [_throwWords] either way are dropped: a
/// mention that makes no claim about failing has nothing to be narrow about.
List<_Passage> _throwPassages(String path, Set<String> mentions) {
  final lines = File(path).readAsLinesSync();
  final bounds = _blockBounds(lines);
  final passages = <_Passage>[];
  final seen = <int>{};

  for (var i = 0; i < lines.length; i++) {
    final line = _asRead(lines[i]);
    if (!mentions.any(line.contains)) continue;

    if (_standsAlone(lines[i]) && _throwWords.any(line.contains)) {
      passages.add(_Passage(i + 1, lines[i]));
      continue;
    }

    final block = bounds[i]!;
    if (!seen.add(block.start)) continue;

    final text = lines.getRange(block.start, block.end).join('\n');
    if (!_throwWords.any(_asRead(text).contains)) continue;

    passages.add(_Passage(i + 1, text));
  }

  return passages;
}

/// Half-open line range `[start, end)`.
class _Range {
  const _Range(this.start, this.end);
  final int start;
  final int end;
}

/// The run of markdown each line belongs to.
///
/// Fenced blocks extend backwards over the sentence introducing them, so
/// `Thrown when validation fails:` and the example under it are one run. Blank
/// lines separate paragraphs and belong to neither side.
Map<int, _Range> _blockBounds(List<String> lines) {
  final bounds = <int, _Range>{};

  var i = 0;
  while (i < lines.length) {
    if (lines[i].trim().isEmpty) {
      i++;
      continue;
    }

    final start = i;
    final isFence = lines[i].trimLeft().startsWith('```');
    if (isFence) {
      i++;
      while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
        i++;
      }
      // Include the closing fence when the file has one.
      if (i < lines.length) i++;
    } else {
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        i++;
      }
    }

    final range = _Range(isFence ? _introOf(lines, start) : start, i);
    for (var line = range.start; line < range.end; line++) {
      bounds[line] = range;
    }
  }

  return bounds;
}

/// The first line of the sentence introducing the fenced block at [fence].
///
/// A block is introduced by the paragraph directly above it, separated by one
/// blank line. Anything further off — another block, a heading, or a gap — is
/// not an introduction, and the block starts at its own fence.
int _introOf(List<String> lines, int fence) {
  var i = fence - 1;
  if (i < 0 || lines[i].trim().isNotEmpty) return fence;

  i--;
  final end = i;
  while (i >= 0 && lines[i].trim().isNotEmpty) {
    if (lines[i].trimLeft().startsWith('#') ||
        lines[i].trimLeft().startsWith('```')) {
      return fence;
    }
    i--;
  }

  return end < 0 ? fence : i + 1;
}
