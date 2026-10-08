/// The guard that keeps every page under `doc/` navigable.
///
/// `api_reference_coverage_test.dart` asks whether a page *exists* for every
/// module. This asks the next question: once a reader opens one, can they get
/// around inside it? The two failures are unrelated — a page can exist and be
/// unnavigable, and the second is harder to notice, because a table of contents
/// that is merely incomplete looks exactly like one that is complete.
///
/// Two invariants, both of which have already broken:
///
///  * **A table of contents lists every `##` and `###` heading, in document
///    order, and any deeper heading the page's own body links to.** The
///    preferences guide once omitted its `## Usage Examples` section — the
///    longest worked-example section in the file — so a reader navigating by
///    the contents skipped precisely the part they had come for. The omission
///    was not visible from the contents, which is the whole problem: an
///    incomplete list of sections advertises itself as the complete one.
///
///    The subsection half was the same harm one level down, at scale: fourteen
///    of the module guides listed no `###` at all, so 305 of 384 subsections
///    were unreachable from the only index of their page — `preferences.md`
///    put 514 of its lines behind one entry. The `####` clause is narrower and
///    covers the case no depth policy makes go away: a page that links from its
///    own body to a heading has declared that heading a destination, and an
///    index that then omits it contradicts the page it indexes. Forty-five such
///    headings were found across eight guides.
///
///    Deeper headings are *permitted* beyond that, never required, and never
///    removed: the API summaries index their classes at `####` and are the most
///    navigable pages in the tree.
///  * **Every in-page link resolves to a heading.** A `](#anchor)` that matches
///    no heading is a link that silently does nothing when clicked. These
///    guides cross-reference themselves heavily, and a heading rename breaks
///    every link to it without breaking anything a build would notice.
///
/// Neither is a matter of any one page's diligence. Both are invariants across
/// a tree of 39 files that no build step was checking, and an invariant that
/// has already broken is one that will break again — so it is checked here
/// instead of remembered.
///
/// Everything reads the working tree, so a failure names the file, the line and
/// the anchor, and appears the moment the next page lands wrong.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Pages that legitimately carry no table of contents.
///
/// Both are structural exclusions, named one at a time with the reason. This is
/// not, and must not become, a place to park a page whose contents went
/// missing.
const Set<String> _pagesWithoutContents = {
  // An index of the other summaries: the page *is* a table of contents, and a
  // contents block listing its own sections would be a contents of a contents.
  'doc/api/api_summary_index.md',
  // A lookup sheet, not a narrative. Its sections are the types themselves, in
  // alphabetical-ish order, and a reader arrives by searching for a name rather
  // than by reading down a list of them.
  'doc/observable/observable_short_reference.md',
};

/// One heading, as the reader and the linker each see it.
class _Heading {
  /// Creates a heading record.
  const _Heading(this.line, this.level, this.text, this.anchor);

  /// 1-based line number, so a failure can be opened directly.
  final int line;

  /// Number of leading `#` characters.
  final int level;

  /// The heading's source text, `#` markers stripped.
  final String text;

  /// The fragment a link must use to reach it — see [_slug].
  final String anchor;
}

/// One `[label](#anchor)` link.
class _Link {
  /// Creates a link record.
  const _Link(this.line, this.label, this.anchor);

  /// 1-based line number.
  final int line;

  /// The link's visible text.
  final String label;

  /// The fragment it points at, `#` stripped.
  final String anchor;
}

/// The anchor a Markdown renderer derives from [headingText].
///
/// The rule is: drop the inline markup, then keep letters, digits, `-` and `_`,
/// turn spaces into `-`, and lowercase. The order of the first two steps is
/// where this gets subtle, and both orderings were tried against the real tree
/// before this one survived:
///
///  * **Entities are decoded before punctuation is dropped.** A heading written
///    `TomApiEndpoint&lt;ReturnType, RequestType&gt;` renders as
///    `TomApiEndpoint<ReturnType, RequestType>` and anchors as
///    `tomapiendpointreturntype-requesttype`. Dropping the punctuation first
///    would leave the `lt`/`gt` letters behind and invent an anchor no link
///    uses.
///  * **Nothing is treated as an HTML tag.** `<E extends TomObject>` inside a
///    code span is a generic parameter list, not markup, and a tag-stripping
///    pass eats it — turning `` `TomList<E extends TomObject>` `` into
///    `tomlist` when every link to it says `tomliste-extends-tomobject`. The
///    same pass eats the `\<T\>` of an escaped heading. No heading in this tree
///    contains real markup, so the honest rule is that there is none.
String _slug(String headingText) {
  var text = headingText
      // `[label](url)` in a heading contributes only its label.
      .replaceAllMapped(
        RegExp(r'\[([^\]]*)\]\([^)]*\)'),
        (match) => match.group(1)!,
      )
      .replaceAll('`', '')
      .replaceAll('**', '')
      .replaceAll('*', '')
      // A backslash escape says "this punctuation is literal"; the punctuation
      // it protects is dropped below either way, and the backslash never
      // reaches the rendered text.
      .replaceAll(r'\', '');

  text = _decodeEntities(text).trim().toLowerCase();

  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (RegExp(r'[a-z0-9\-_]').hasMatch(char)) {
      buffer.write(char);
    } else if (char == ' ') {
      buffer.write('-');
    }
  }
  return buffer.toString();
}

/// The HTML entities that appear in this tree's headings.
///
/// A named list rather than a general decoder: these three are what escaping a
/// generic parameter list produces, and an entity that is not here would fail
/// loudly as a wrong anchor rather than be silently mis-decoded.
String _decodeEntities(String text) => text
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');

/// The headings and in-page links of [file], ignoring fenced code blocks.
///
/// Fences are skipped because a Dart sample containing a `//` comment line that
/// starts with `#`, or a shell snippet, is not a heading — and because a URL in
/// a code sample is not a link a reader can click.
({List<_Heading> headings, List<_Link> links}) _parse(File file) {
  final headings = <_Heading>[];
  final links = <_Link>[];
  final headingPattern = RegExp(r'^(#{1,6}) (.+)$');
  final linkPattern = RegExp(r'\[([^\]]+)\]\(#([^)]+)\)');

  var inFence = false;
  final lines = file.readAsLinesSync();
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    if (line.trimLeft().startsWith('```')) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;

    final heading = headingPattern.firstMatch(line);
    if (heading != null) {
      final text = heading.group(2)!;
      headings.add(
        _Heading(index + 1, heading.group(1)!.length, text, _slug(text)),
      );
    }
    for (final link in linkPattern.allMatches(line)) {
      links.add(_Link(index + 1, link.group(1)!, link.group(2)!));
    }
  }
  return (headings: headings, links: links);
}

/// Every anchor [headings] makes reachable.
///
/// Repeated headings are disambiguated the way a renderer does it — the first
/// `### Constructors` is `constructors`, the next `constructors-1`. The API
/// summaries repeat a handful of section names once per class, so without this
/// every summary but the smallest would look like it had colliding anchors.
Set<String> _anchorsOf(List<_Heading> headings) =>
    _anchorList(headings).toSet();

/// The same anchors, one per heading and in the same order.
///
/// A list rather than a set, because [_requiredAnchors] needs to say *which*
/// heading an anchor belongs to. The set form above is the membership question
/// and would answer the positional one only by the accident that the values
/// happen to be unique.
List<String> _anchorList(List<_Heading> headings) {
  final seen = <String, int>{};
  return [
    for (final heading in headings)
      () {
        final count = seen.update(
          heading.anchor,
          (value) => value + 1,
          ifAbsent: () => 0,
        );
        return count == 0 ? heading.anchor : '${heading.anchor}-$count';
      }(),
  ];
}

/// Every Markdown page under `doc/`, sorted by path.
List<File> _pages() =>
    Directory('doc')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.md'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// The heading that opens the table of contents, or `null` if there is none.
_Heading? _contentsHeading(List<_Heading> headings) {
  for (final heading in headings) {
    if (heading.level == 2 && heading.anchor == 'table-of-contents') {
      return heading;
    }
  }
  return null;
}

/// The anchors listed inside the table of contents of [headings] / [links].
///
/// The block runs from the contents heading to the next heading at `##` or
/// above, which is how a reader sees it too.
List<String> _contentsAnchors(List<_Heading> headings, List<_Link> links) {
  final contents = _contentsHeading(headings);
  if (contents == null) return const [];

  var end = 1 << 30;
  for (final heading in headings) {
    if (heading.line > contents.line && heading.level <= 2) {
      end = heading.line;
      break;
    }
  }
  return links
      .where((link) => link.line > contents.line && link.line < end)
      .map((link) => link.anchor)
      .toList();
}

/// The anchors a contents block must list, in document order.
///
/// Every `##` and `###`, plus any deeper heading [bodyLinks] shows the page
/// linking to from outside its own contents block. The contents heading itself
/// is excluded — an entry for the contents is a link to where the reader
/// already is.
///
/// Disambiguated by [_anchorList], so a page with two `### Methods` is compared
/// against the anchors a renderer would actually produce rather than against
/// the first one twice.
List<String> _requiredAnchors(List<_Heading> headings, Set<String> bodyLinks) {
  final anchors = _anchorList(headings);
  final required = <String>[];
  for (var index = 0; index < headings.length; index++) {
    final heading = headings[index];
    final anchor = anchors[index];
    if (anchor == 'table-of-contents' || heading.level < 2) continue;
    if (heading.level <= 3 || bodyLinks.contains(anchor)) {
      required.add(anchor);
    }
  }
  return required;
}

/// The anchors the page links to from outside its contents block.
Set<String> _bodyLinkAnchors(List<_Heading> headings, List<_Link> links) {
  final contents = _contentsHeading(headings);
  if (contents == null) return const {};
  var end = 1 << 30;
  for (final heading in headings) {
    if (heading.line > contents.line && heading.level <= 2) {
      end = heading.line;
      break;
    }
  }
  return links
      .where((link) => link.line <= contents.line || link.line >= end)
      .map((link) => link.anchor)
      .toSet();
}

void main() {
  group('every doc page is navigable', () {
    test('every page has a table of contents', () {
      final missing = <String>[];
      for (final page in _pages()) {
        if (_pagesWithoutContents.contains(page.path)) continue;
        if (_contentsHeading(_parse(page).headings) == null) {
          missing.add(page.path);
        }
      }

      expect(
        missing,
        isEmpty,
        reason:
            'These pages have no "## Table of Contents": '
            '${missing.join(', ')}. Add one, or — if the page is genuinely a '
            'lookup sheet rather than a narrative — name it in '
            '_pagesWithoutContents with the reason.',
      );
    });

    test('a table of contents lists every section and subsection, in document '
        'order', () {
      final wrong = <String>[];
      for (final page in _pages()) {
        final parsed = _parse(page);
        if (_contentsHeading(parsed.headings) == null) continue;

        final required = _requiredAnchors(
          parsed.headings,
          _bodyLinkAnchors(parsed.headings, parsed.links),
        );
        final listed = _contentsAnchors(parsed.headings, parsed.links);
        // Only the required entries are compared, so a contents block that
        // indexes deeper than the rule asks — as the API summaries do, down to
        // each class — is free to, and is never asked to give that up. What it
        // may not do is skip one or list two out of order.
        final listedRequired = listed.where(required.contains).toList();

        if (listedRequired.toString() != required.toString()) {
          final omitted = required.where((s) => !listed.contains(s)).toList();
          final fault = omitted.isEmpty
              ? 'listed out of document order'
              : 'omits ${omitted.join(', ')}';
          wrong.add(
            '${page.path}: $fault '
            '(contents lists ${listedRequired.join(', ')}; '
            'required are ${required.join(', ')})',
          );
        }
      }

      expect(
        wrong,
        isEmpty,
        reason:
            'These tables of contents do not match their pages:\n'
            '  ${wrong.join('\n  ')}\n'
            'A contents block that omits a heading still reads as the complete '
            'list, so the part it skips is one no reader navigating by the '
            'contents will find. Every `##` and `###` must be listed, and so '
            'must any deeper heading the page links to from its own body — a '
            'page that calls a heading worth linking to and then leaves it out '
            'of its own index contradicts itself.',
      );
    });

    test('every in-page link resolves to a heading', () {
      final dead = <String>[];
      for (final page in _pages()) {
        final parsed = _parse(page);
        final anchors = _anchorsOf(parsed.headings);
        for (final link in parsed.links) {
          if (!anchors.contains(link.anchor)) {
            dead.add(
              '${page.path}:${link.line}: '
              '[${link.label}](#${link.anchor})',
            );
          }
        }
      }

      expect(
        dead,
        isEmpty,
        reason:
            'These links point at no heading on their own page:\n'
            '  ${dead.join('\n  ')}\n'
            'A link whose fragment matches nothing does nothing when clicked, '
            'and nothing else reports it — a heading can be renamed without '
            'breaking any build.',
      );
    });
  });

  // `tool/check_doc_tocs.py` computes the same anchors in Python, and the two
  // once disagreed about a repeated heading: the gate reported a page that
  // renders correctly. Both read one case file, so agreement is asserted on
  // every run of either rather than assumed.
  group('anchors agree with check_doc_tocs.py', () {
    final shared =
        jsonDecode(File(_sharedAnchorCases).readAsStringSync())
            as Map<String, dynamic>;

    test('each shared case slugs and disambiguates to the same anchors', () {
      for (final raw in shared['anchors'] as List) {
        final case_ = raw as Map<String, dynamic>;
        final texts = (case_['headings'] as List).cast<String>();
        final headings = [
          for (final (index, text) in texts.indexed)
            _Heading(index + 1, 2, text, _slug(text)),
        ];
        expect(
          _anchorList(headings),
          (case_['anchors'] as List).cast<String>(),
          reason: 'headings $texts',
        );
      }
    });

    test('a page that repeats a section name is navigable', () {
      final dir = Directory.systemTemp.createTempSync('doc_navigation_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final page = File('${dir.path}/repeated.md')
        ..writeAsStringSync(shared['page'] as String);
      final parsed = _parse(page);

      final required = _requiredAnchors(
        parsed.headings,
        _bodyLinkAnchors(parsed.headings, parsed.links),
      );
      final listed = _contentsAnchors(parsed.headings, parsed.links);
      expect(listed.where(required.contains).toList(), required);
      expect(required, ['methods', 'details', 'methods-1', 'details-1']);

      final anchors = _anchorsOf(parsed.headings);
      for (final link in parsed.links) {
        expect(anchors, contains(link.anchor), reason: '#${link.anchor}');
      }
    });
  });
}

/// The heading-anchor cases this test shares with `tool/check_doc_tocs.py`,
/// relative to the package root the suite runs in.
const _sharedAnchorCases = '../tool/heading_anchor_cases.json';
