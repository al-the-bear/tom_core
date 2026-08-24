/// The guard that keeps `doc/api_reference/` a mirror of `lib/` (CSEXC6).
///
/// `doc/api_reference/` claims, by existing, that it documents the package.
/// Nothing enforced that claim, and it drifted: five modules — audit,
/// scheduling, messaging, export, file_storage — shipped with a full narrative
/// guide and no API summary at all. That was not any one module's omission.
/// Each shipped what its own done-bar asked for; the gap was in an invariant
/// nobody was checking, and an invariant five modules have already broken is
/// one that will break a sixth time.
///
/// So the invariant is checked here instead of remembered. Three sets must
/// agree, keyed by module directory name:
///
///  * the module directories under `lib/src/tomserver/`;
///  * the narrative guides `doc/<module>.md`;
///  * the API summaries `doc/api_reference/api_summary_<module>.md`.
///
/// Both directions matter. A module without a summary is undocumented; a
/// summary without a module documents something that no longer exists, which
/// is worse, because a reader cannot tell a stale page from a current one.
///
/// The fourth test covers the index: `api_summary_index.md` is the entry point,
/// and an index that omits part of the package reads as complete while being
/// wrong. A summary nobody can navigate to is only marginally better than one
/// that was never written.
///
/// The next group checks the same invariant one level finer. Each guide opens
/// with an Overview table headed `| Type | Kind | Purpose |`, which claims by
/// its heading to be the module's type list — and the claim drifts the same way
/// the file-level one did, because a type added later has no reason to send its
/// author back to a table written when the module was young. A partial table is
/// worse than none: a reader who finds fourteen of twenty types has no signal
/// that six are missing, so they conclude the six do not exist.
///
/// The last group goes one level finer again, for one class. A summary's
/// `#### Properties` table makes the same completeness claim about a class's
/// fields that the Overview table makes about a module's types, and
/// [TomBaseServerConfiguration] had drifted furthest: it declared 48 fields and
/// the table listed 25, so the whole server self-login block, the whole
/// outbound-mail block and the whole outbound-SMS block — 23 deployment-facing
/// settings, four of them secret-bearing — were absent from the page a deployer
/// reads to find out what can be configured. That class is checked because it
/// is the one whose readers are operators rather than callers: an undocumented
/// method can be found in the source by the developer calling it, whereas an
/// undocumented setting is invisible to the person who needed to set it.
///
/// The final group goes one level finer still, and changes the question from
/// *completeness* to *attribution*. Every previous check asks whether a member
/// is documented somewhere; this one asks whether the class it is documented
/// **under** is the class that declares it. A summary is organised as
/// `#### <ClassName>` sections, so a row's position is itself a claim of
/// ownership — and that claim is unchecked by every test above, which would
/// be equally satisfied by a correct row filed under the wrong heading.
///
/// It drifts in a way the completeness checks cannot see. `mapGroupedRow` is a
/// static of [MariaDbDatasource], and the datasources completion document
/// listed it under `MariadbPreparedStatement` — the class it is *about*,
/// being the reading half of a grouped query, not the class it is *on*. A
/// reader comparing two documents that disagree about where a public static
/// lives cannot tell which one to believe, and a reader trusting the wrong one
/// writes `MariadbPreparedStatement.mapGroupedRow(...)` and gets a compile
/// error naming a class they were told to use.
///
/// So ownership is derived from the source rather than reviewed. The parser is
/// deliberately three-valued: a member is *declared*, *absent*, or
/// **undecidable** — the last when the class inherits from a type this
/// package does not declare, as [TomConfigurationException] does from the
/// kernel's exception base. Only *absent* fails. Reporting a member missing
/// because the parser could not see the class that declares it would be a
/// false alarm, and a guard that cries wolf is turned off.
///
/// The last group changes the question a third time. Attribution asks *whose*
/// member this is; this one asks what the reader is being *asked to do* about
/// it. In a contract listing — the `abstract class X { … }` blocks the module
/// guides open a chapter with — a bare declaration is a demand and one with a
/// body is a gift, and nothing checked which one the source meant.
///
/// Both directions of the mistake cost something, and they cost different
/// things. A concrete member shown bare is work invented for the reader: they
/// implement what they already had, and the override silently displaces a
/// default that was load-bearing. `TomMessageTransport.supportsCopies` and
/// `supportsAttachments` default to `false` precisely so that a transport which
/// has never considered attachments cannot be handed one — presenting them as
/// abstract turns a safe default into a chore, and a chore done carelessly
/// answers `true`. The opposite mistake is louder but cheaper: an abstract
/// member shown with a body reads as optional, is skipped, and the class does
/// not compile.
///
/// The comparison is symmetric, and that is what makes it sound. What is
/// measured on both sides is whether a declaration ends at a `;` or at a body,
/// which for anything that *can* be abstract is abstractness, and for a field
/// is merely "no initialiser". Two exclusions keep the shapes comparable: a
/// `static` and a constructor are never abstract however they are written, so a
/// bodiless one is not evidence of anything.
///
/// Everything here reads the working tree, so the failure names the missing
/// file, type or field and appears the moment the next one lands.
library;

import 'dart:io';

import 'package:test/test.dart';

/// Module directory names under `lib/src/tomserver/`, sorted.
///
/// This is the anchor set: it is the code, so it cannot itself be out of date.
List<String> _modules() =>
    Directory('lib/src/tomserver')
        .listSync()
        .whereType<Directory>()
        .map(
          (entry) => entry.uri.pathSegments[entry.uri.pathSegments.length - 2],
        )
        .toList()
      ..sort();

/// Base names of the markdown files directly under [directory], sorted.
///
/// `stripPrefix` removes the naming prefix the summaries carry, so both sets
/// come back keyed by plain module name and can be compared directly.
List<String> _docs(String directory, {String stripPrefix = ''}) =>
    Directory(directory)
        .listSync()
        .whereType<File>()
        .map((entry) => entry.uri.pathSegments.last)
        .where((name) => name.endsWith('.md'))
        .map((name) => name.substring(0, name.length - '.md'.length))
        .where((name) => name.startsWith(stripPrefix))
        .map((name) => name.substring(stripPrefix.length))
        .toList()
      ..sort();

/// Matches a top-level type declaration, anchored at column zero.
///
/// Dart has no nested types, so a declaration that is indented is inside
/// something and not part of the module's surface — the anchor is what
/// distinguishes them, and it is why this stays a regex rather than growing an
/// `analyzer` dependency for four lines of parsing.
final RegExp _typeDeclaration = RegExp(
  r'^(?:abstract\s+|sealed\s+|final\s+|base\s+|interface\s+|mixin\s+)*'
  r'(?:class|enum|mixin|extension|typedef)\s+([A-Za-z_][A-Za-z0-9_]*)',
  multiLine: true,
);

/// Matches one `export 'src/tomserver/<module>/<file>';` line of the barrel.
final RegExp _barrelExport = RegExp(
  r"^export 'src/tomserver/([^/]+)/([^']+)';",
  multiLine: true,
);

/// The public types the package barrel exports for [module], sorted.
///
/// Read through the barrel rather than by listing the module directory,
/// because the two are not the same set: a file the barrel does not export is
/// module-internal, and documenting it in a table headed "Type" would promise
/// an API that a consumer cannot import.
List<String> _exportedTypes(String module) {
  final barrel = File('lib/tom_core_server.dart').readAsStringSync();
  final names = <String>{};
  for (final export in _barrelExport.allMatches(barrel)) {
    if (export.group(1) != module) continue;
    final source = File('lib/src/tomserver/$module/${export.group(2)}')
        .readAsStringSync()
        // Doc comments quote code, and a quoted declaration is not one.
        .replaceAll(RegExp(r'^\s*///.*$', multiLine: true), '');
    for (final declaration in _typeDeclaration.allMatches(source)) {
      final name = declaration.group(1)!;
      if (!name.startsWith('_')) names.add(name);
    }
  }
  return names.toList()..sort();
}

/// The type names the first column of `doc/<module>.md`'s Overview table
/// carries, sorted — or `null` when the guide has no such table.
///
/// A cell may name more than one type (the delegation row names three), so
/// every backticked identifier in the cell counts.
List<String>? _overviewTableTypes(String module) {
  final lines = File('doc/$module.md').readAsLinesSync();
  final heading = lines.indexWhere((line) => line.startsWith('| Type |'));
  if (heading < 0) return null;

  final names = <String>{};
  // +2 skips the heading and the `| ---- |` separator beneath it.
  for (final line in lines.skip(heading + 2)) {
    if (!line.startsWith('|')) break;
    final cell = line.split('|')[1];
    names.addAll(
      RegExp(
        r'`([A-Za-z_][A-Za-z0-9_]*)`',
      ).allMatches(cell).map((match) => match.group(1)!),
    );
  }
  return names.toList()..sort();
}

/// The body of `class <className>`, from its opening brace to the end of the
/// file, with the constructs that would otherwise be misread removed.
///
/// A multi-line default — the PEM certificate pair — is data whose lines would
/// be taken for declarations, and a block comment can hold anything at all.
/// Dartdoc is deliberately *kept*: [_secretBearingFields] reads it.
String _classBody(String path, String className) {
  final source = File(path).readAsStringSync();
  final start = source.indexOf('class $className {');
  if (start < 0) return '';
  return source
      .substring(start)
      .replaceAll(RegExp(r"'''[\s\S]*?'''"), "''")
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
}

/// The field name [line] declares, or `null` when it declares no field.
///
/// A declaration is exactly two spaces of indent, ends in `;`, and has a name
/// that is not followed by a parameter list. That last rule is what separates
/// `void setValues(Map<…> values);` from a field — without it the census counts
/// `values`, the method's final parameter, as a 49th field and then reports it
/// missing from a table that is in fact complete.
///
/// A regex rather than the `analyzer` package for the same reason
/// [_typeDeclaration] is one: this is a handful of lines of parsing against a
/// file whose layout the package's own formatter guarantees.
String? _fieldNameOf(String line) {
  if (!line.startsWith('  ') || line.startsWith('   ')) return null;
  final statement = line.trimRight();
  if (!statement.endsWith(';')) return null;

  // Everything left of the initialiser: a field's name is the last identifier
  // there, a method's is followed by its parameters.
  final declaration = statement
      .substring(0, statement.length - 1)
      .split('=')
      .first
      .trimRight();
  if (declaration.endsWith(')')) return null;

  final name = RegExp(r'([A-Za-z_][A-Za-z0-9_]*)$').firstMatch(declaration);
  if (name == null || name.group(1)!.startsWith('_')) return null;
  return name.group(1)!;
}

/// The instance field names a class declares in its source file, in source
/// order.
List<String> _declaredFields(String path, String className) {
  final body = _classBody(
    path,
    className,
  ).replaceAll(RegExp(r'^\s*///.*$', multiLine: true), '');

  final fields = <String>[];
  for (final line in body.split('\n')) {
    final name = _fieldNameOf(line);
    if (name != null) fields.add(name);
  }
  return fields;
}

/// The declared fields whose own dartdoc calls them **secret-bearing**, in
/// source order.
///
/// Derived rather than listed, so marking a new credential in the source is
/// what puts it on the guide's checked list — the alternative is a literal set
/// here, which is the same "written once, never revisited" failure this file
/// exists to close.
List<String> _secretBearingFields(String path, String className) {
  final secrets = <String>[];
  final doc = <String>[];
  for (final line in _classBody(path, className).split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('///')) {
      doc.add(trimmed);
      continue;
    }
    // A blank line detaches a dartdoc from what follows it.
    if (trimmed.isEmpty) {
      doc.clear();
      continue;
    }
    if (doc.isEmpty) continue;
    final name = _fieldNameOf(line);
    if (name != null &&
        doc.join(' ').toLowerCase().contains('secret-bearing')) {
      secrets.add(name);
    }
    doc.clear();
  }
  return secrets;
}

/// Whether [field] belongs to one of the three deployment-facing blocks the
/// configuration guide documents: server self-login, outbound mail, outbound
/// SMS.
///
/// Matched by name rather than by a listed set, so a tenth `smtp*` setting is
/// covered by the guard the day it is declared.
bool _isDeploymentSetting(String field) =>
    field == 'authServerLoginUri' ||
    field.startsWith('serviceAccount') ||
    field.startsWith('smtp') ||
    field.startsWith('sms');

/// The settings the tables under `## Deployment Settings` in
/// `doc/configuration.md` carry: their names in document order, and the subset
/// whose row marks them secret-bearing.
///
/// Only the first column counts. A setting named in passing in another row's
/// prose is a cross-reference, not an entry — the claim being checked is that
/// the setting has a row of its own saying what it decides. The block-switch
/// table contributes nothing, because its first column names blocks rather than
/// settings.
(List<String>, Set<String>) _guideDeploymentSettings() {
  final lines = File('doc/configuration.md').readAsLinesSync();
  final start = lines.indexWhere(
    (line) => line.trim() == '## Deployment Settings',
  );
  if (start < 0) return (const [], const {});

  final names = <String>[];
  final secrets = <String>{};
  for (final line in lines.skip(start + 1)) {
    if (line.startsWith('## ')) break;
    if (!line.startsWith('|')) continue;
    final cell = RegExp(
      r'`([A-Za-z_][A-Za-z0-9_]*)`',
    ).firstMatch(line.split('|')[1]);
    if (cell == null) continue;
    names.add(cell.group(1)!);
    if (line.toLowerCase().contains('secret-bearing')) {
      secrets.add(cell.group(1)!);
    }
  }
  return (names, secrets);
}

/// The property names the `#### Properties` table under `### <className>` in
/// `doc/api_reference/api_summary_<module>.md` carries, in table order.
///
/// Scoped to the class's own section, because one summary documents several
/// classes and each has a Properties table of its own.
List<String> _summaryProperties(String module, String className) {
  final lines = File(
    'doc/api_reference/api_summary_$module.md',
  ).readAsLinesSync();

  final section = lines.indexWhere((line) => line.trim() == '### $className');
  if (section < 0) return const [];
  final heading = lines.indexWhere(
    (line) => line.startsWith('| Property |'),
    section,
  );
  if (heading < 0) return const [];

  final names = <String>[];
  // +2 skips the heading and the `| -------- |` separator beneath it.
  for (final line in lines.skip(heading + 2)) {
    if (!line.startsWith('|')) break;
    final cell = RegExp(
      r'`([A-Za-z_][A-Za-z0-9_]*)`',
    ).firstMatch(line.split('|')[1]);
    if (cell != null) names.add(cell.group(1)!);
  }
  return names;
}

/// One type declared by the package, with what it declares and what it
/// inherits from.
class _Declaration {
  _Declaration(this.name);

  final String name;

  /// Whether the type is declared `abstract`.
  bool isAbstract = false;

  /// Member names declared directly on this type — fields, getters, setters,
  /// methods, statics, named constructors and enum values alike. The kind does
  /// not matter to the question being asked, which is only whether the name
  /// belongs to this class at all.
  final Set<String> members = {};

  /// The members declared without a body or an initialiser — the ones whose
  /// declaration ends at a `;`.
  ///
  /// For a method or a getter that is exactly abstractness. For a field it is
  /// "no initialiser", which is not the same thing — a bare `List<Type> types;`
  /// is a real field, not a demand on a subclass. The distinction does not
  /// weaken the comparison this feeds, because both sides of it are measured
  /// the same way: what is being asked is whether a document and the source
  /// agree about the *shape* of a declaration, and for everything that can be
  /// abstract, that shape is abstractness.
  final Set<String> bodilessMembers = {};

  /// The names in the `extends` / `implements` / `with` clause.
  final Set<String> supertypes = {};
}

/// Matches a type declaration that can own members, anchored at column zero.
///
/// `typedef` and `extension` are deliberately absent. A typedef declares no
/// members, and an extension's members belong to the type it extends rather
/// than to itself — including either would attribute members to a name that
/// does not own them, which is the error this group exists to catch.
final RegExp _ownerDeclaration = RegExp(
  r'^(?:abstract\s+|final\s+|sealed\s+|base\s+|interface\s+|mixin\s+)*'
  r'(?:class|mixin|enum|extension type)\s+([A-Za-z_][A-Za-z0-9_]*)',
);

/// The modifiers that may precede a member's type, stripped before the name is
/// looked for.
///
/// `static` is the load-bearing one: a record return type makes the
/// declaration read `static (String, List<String>) toPositionalStatement(…)`,
/// where `static (` is indistinguishable from a call and would otherwise be
/// taken for the member's name.
final RegExp _memberModifiers = RegExp(
  r'^\s*(?:@\w+\s+|static\s+|final\s+|late\s+|const\s+|external\s+'
  r'|abstract\s+|covariant\s+|factory\s+)*',
);

/// An identifier followed by an argument list — the shape of a method or
/// constructor declaration, and the anchor the member name is read from.
final RegExp _parameterList = RegExp(r'(\w+)\s*(?:<[^<>]*>)?\s*\(');

/// The last identifier of a string — a field or getter's name, once the
/// initialiser and the trailing `;` are gone.
final RegExp _trailingIdentifier = RegExp(r'([A-Za-z_][A-Za-z0-9_]*)\s*$');

/// An enum value: an identifier opening a two-space-indented line.
final RegExp _enumValue = RegExp(r'^  ([a-z]\w*)\s*[,;(]');

/// The clause naming the supertypes, and the type names inside it.
final RegExp _supertypeClause = RegExp(
  r'\b(?:extends|implements|with)\s+([\w\s,]+)',
);
final RegExp _supertypeName = RegExp(r'\b([A-Z]\w+)');

/// [source] with every type-argument list removed.
///
/// Applied before the supertypes are read, because the *first* `extends` on
/// `class MariadbPreparedStatement<T extends Object> extends
/// TomPreparedStatement<T>` is the bound inside the type parameters. Reading
/// from there makes `Object` a supertype, and since this package does not
/// declare `Object` every lookup on the class becomes undecidable — the guard
/// would go quiet on exactly the class the misfiled static was blamed on.
String _withoutTypeArguments(String source) {
  final generic = RegExp(r'<[^<>]*>');
  var result = source;
  String previous;
  do {
    previous = result;
    result = result.replaceAll(generic, '');
  } while (previous != result);
  return result;
}

/// The offset in [line] where the declaration stops and the body or the
/// initialiser starts, i.e. the first `{`, `=` or `=>` outside any brackets.
///
/// Depth is what makes this correct rather than approximate. Both characters
/// occur *inside* a parameter list — `({String sentence, …})` as a record
/// return type, `{int retries = 3}` as an optional parameter — and cutting
/// there truncates the declaration before its name. Only a delimiter at depth
/// zero ends the declaration.
int _declarationEnd(String line) {
  var depth = 0;
  for (var i = 0; i < line.length; i++) {
    final character = line[i];
    if (character == '(' || character == '[') {
      depth++;
    } else if (character == ')' || character == ']') {
      depth--;
    } else if (depth == 0) {
      if (character == '{') return i;
      if (character != '=') continue;
      // `==`, `!=`, `<=` and `>=` are comparisons in a default value, not the
      // start of one. `=>` is an expression body, so cutting at it is right.
      final previous = i == 0 ? '' : line[i - 1];
      final next = i + 1 < line.length ? line[i + 1] : '';
      if ('=!<>'.contains(previous) || next == '=') continue;
      return i;
    }
  }
  return line.length;
}

/// [line] with any trailing `//` comment removed.
///
/// A comment is invisible to a reader and must be invisible to the parser, and
/// it is not: `bool get supportsCopies;   // Cc / Bcc` ends at its `;`, so
/// nothing after it is part of the declaration, and the name-of-last-resort
/// scan reads `Bcc` as the member. That misnames a member precisely when it is
/// *bodiless* — the case this whole comparison exists to catch — so the member
/// resolves against no class, is skipped as inherited, and the disagreement
/// passes unseen. Contract listings annotate their terse members exactly this
/// way, which is why the blind spot sat over the members most worth checking.
///
/// The quote tracking is what keeps `'http://…'` intact. It is per-line, so a
/// `//` inside a *multi-line* string would still be cut; those are stripped
/// wholesale before [_parseDeclarations] ever sees them, and no listing in
/// `doc/` contains one.
String _withoutLineComment(String line) {
  String? quote;
  for (var i = 0; i < line.length; i++) {
    final character = line[i];
    if (quote != null) {
      if (character == r'\') {
        i++;
      } else if (character == quote) {
        quote = null;
      }
      continue;
    }
    if (character == "'" || character == '"') {
      quote = character;
    } else if (character == '/' && i + 1 < line.length && line[i + 1] == '/') {
      return line.substring(0, i);
    }
  }
  return line;
}

/// Whether the declaration starting at [index] ends at a `;` rather than at a
/// body or an initialiser.
///
/// The scan runs *across* lines, which is the whole reason this exists next to
/// [_declarationEnd] rather than reusing it. A declaration need not fit on one
/// line — a wrapped parameter list closes on a later one — and a single-line
/// verdict reads every wrapped method as bodiless, i.e. as abstract. That would
/// be a false alarm on the most elaborate signatures in the package, which are
/// precisely the ones a document is most likely to get wrong.
bool _endsWithoutBody(List<String> lines, int index) {
  var depth = 0;
  for (var i = index; i < lines.length && i < index + 40; i++) {
    final line = _withoutLineComment(lines[i]);
    if (i > index && line.trimLeft().startsWith('///')) continue;
    for (var j = 0; j < line.length; j++) {
      final character = line[j];
      if (character == '(' || character == '[') {
        depth++;
      } else if (character == ')' || character == ']') {
        depth--;
      } else if (depth == 0) {
        if (character == '{') return false;
        if (character == ';') return true;
        if (character != '=') continue;
        final previous = j == 0 ? '' : line[j - 1];
        final next = j + 1 < line.length ? line[j + 1] : '';
        if ('=!<>'.contains(previous) || next == '=') continue;
        return false;
      }
    }
  }
  return false;
}

/// The member [line] declares, or `null` when it declares none.
///
/// Two shapes, distinguished by whether the declaration carries a parameter
/// list. With one, the name is the identifier introducing it; without one, the
/// name is the last identifier before the initialiser. `Function` is skipped
/// because `final DateTime Function() clock;` is a *field* whose type happens
/// to spell a parameter list.
String? _memberNameOf(String rawLine) {
  if (!rawLine.startsWith('  ') || rawLine.startsWith('   ')) return null;
  final line = _withoutLineComment(rawLine).trimRight();

  var head = line.substring(0, _declarationEnd(line));
  head = head.substring(_memberModifiers.matchAsPrefix(head)?.end ?? 0);

  for (final match in _parameterList.allMatches(head)) {
    if (match.group(1) != 'Function') return match.group(1);
  }

  var remainder = head.trimRight();
  if (remainder.endsWith(';')) {
    remainder = remainder.substring(0, remainder.length - 1).trimRight();
  }
  return _trailingIdentifier.firstMatch(remainder)?.group(1);
}

/// Every type the package declares, keyed by name.
///
/// The multi-line string literals and block comments go first: their contents
/// are unindented prose, and a line of it at column zero would be read as the
/// end of the enclosing class, silently truncating the member list of whatever
/// class happened to contain one.
Map<String, _Declaration> _parseDeclarations() {
  final declarations = <String, _Declaration>{};
  final sources = Directory('lib/src/tomserver')
      .listSync(recursive: true)
      .whereType<File>()
      .where((entry) => entry.path.endsWith('.dart'));

  for (final file in sources) {
    final source = file
        .readAsStringSync()
        .replaceAll(RegExp(r"'''[\s\S]*?'''"), "''")
        .replaceAll(RegExp(r'"""[\s\S]*?"""'), '""')
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');

    _Declaration? current;
    // The declaration header, while it is still open. A long type parameter
    // list is wrapped across lines and closes with a `>` at column zero, which
    // read as the end of the class body and dropped every member of the four
    // classes declared that way — `TomEndpointBase` and `TomReference` among
    // them. So the header is accumulated until its `{`, and the supertypes are
    // read from the whole of it rather than from its first line.
    final header = <String>[];

    void readSupertypes(String text) {
      final clause = _supertypeClause.firstMatch(_withoutTypeArguments(text));
      if (clause == null) return;
      current!.supertypes.addAll(
        _supertypeName.allMatches(clause.group(1)!).map((m) => m.group(1)!),
      );
    }

    final lines = source.split('\n');
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (line.trimLeft().startsWith('///')) continue;

      if (header.isNotEmpty) {
        header.add(line);
        // `;` ends a mixin application (`class A = B with C;`), which has no
        // body at all.
        if (!line.contains('{') && !line.contains(';')) continue;
        readSupertypes(header.join(' '));
        header.clear();
        continue;
      }

      final declared = _ownerDeclaration.firstMatch(line);
      if (declared != null) {
        final name = declared.group(1)!;
        current = declarations.putIfAbsent(name, () => _Declaration(name));
        current.isAbstract = line.startsWith('abstract ');
        if (line.contains('{')) {
          readSupertypes(line);
        } else {
          header.add(line);
        }
        continue;
      }
      if (current == null) continue;
      // An unindented line has left the class body behind.
      if (line.isNotEmpty && !line.startsWith(' ')) {
        current = null;
        continue;
      }

      final member = _memberNameOf(line);
      if (member != null) {
        current.members.add(member);
        if (_endsWithoutBody(lines, index)) current.bodilessMembers.add(member);
      }
      final value = _enumValue.firstMatch(line);
      if (value != null) current.members.add(value.group(1)!);
    }
  }
  return declarations;
}

/// Parsed once: every test in the attribution group reads the same census, and
/// re-walking the package per test would be the slowest thing in the suite.
final Map<String, _Declaration> _declarations = _parseDeclarations();

/// Whether [type] declares or inherits [member] — `null` when the answer
/// cannot be established because some ancestor is not declared in this
/// package.
///
/// Inheritance is walked for a deliberate reason and with a known limit. It
/// must be walked, or every member a class inherits would read as absent. The
/// limit is that Dart does not inherit *statics*, so a parent's static
/// documented under a child would pass. That direction is not the drift being
/// chased and would take a real element model to distinguish, whereas the
/// misfiling this catches — a static on the wrong sibling class — does not.
bool? _resolveMember(String type, String member, [Set<String>? visited]) {
  final seen = visited ?? <String>{};
  if (!seen.add(type)) return false;

  final declaration = _declarations[type];
  if (declaration == null) return null;
  if (declaration.members.contains(member)) return true;

  var undecided = false;
  for (final parent in declaration.supertypes) {
    final inherited = _resolveMember(parent, member, seen);
    if (inherited == true) return true;
    if (inherited == null) undecided = true;
  }
  return undecided ? null : false;
}

/// One member row of a summary, with the class its heading attributes it to.
typedef _Attribution = ({String file, int line, String type, String member});

/// The sub-headings that divide a class's section. They group the rows by kind
/// and must not be read as a new class, or every table under one would be
/// skipped.
const Set<String> _memberSectionHeadings = {
  'Properties',
  'Methods',
  'Static Methods',
  'Constructors',
  'Constructor',
  'Factory Constructors',
  'Static Properties',
  'Static Fields',
  'Fields',
  'Enum Values',
  'Values',
  'Operators',
  'Static Members',
  'Properties and Methods',
};

/// Every member row in `doc/api_reference/`, paired with the class it is filed
/// under.
///
/// A heading is taken for a class when it names one the package declares —
/// rather than by its depth, which is not uniform: the audit summary files
/// classes at `###` and the datasources summary at `####`. Any other heading
/// ends the current class, so rows under `## Overview` are attributed to
/// nothing instead of to whichever class was last seen.
///
/// A generic class is headed with its type parameters HTML-escaped
/// (`#### MariadbPreparedStatement&lt;T&gt;`), so the parameters are stripped
/// before the name is matched. Without that every generic class is skipped
/// silently — twenty-one of them, including both prepared-statement classes,
/// which is to say the guard would be blind in exactly the section that held
/// the misfiled static.
List<_Attribution> _attributions() {
  final heading = RegExp(r'^#{2,6}\s+(.*?)\s*$');
  final memberRow = RegExp(r'^\|\s*`(\w+)`');
  final typeName = RegExp(r'^[A-Z]\w*$');
  final typeParameters = RegExp(r'&lt;.*&gt;|<[^<>]*>');

  final found = <_Attribution>[];
  final summaries = Directory('doc/api_reference')
      .listSync()
      .whereType<File>()
      .where((e) => e.uri.pathSegments.last.startsWith('api_summary_'));

  for (final file in summaries) {
    final name = file.uri.pathSegments.last;
    String? current;
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final title = heading.firstMatch(lines[i])?.group(1);
      if (title != null) {
        if (_memberSectionHeadings.contains(title)) continue;
        final type = title.replaceAll(typeParameters, '').trim();
        final isType =
            typeName.hasMatch(type) && _declarations.containsKey(type);
        current = isType ? type : null;
        continue;
      }
      final member = memberRow.firstMatch(lines[i])?.group(1);
      if (member == null || current == null) continue;
      found.add((file: name, line: i + 1, type: current, member: member));
    }
  }
  return found;
}

/// One member as a module document's class listing presents it.
typedef _ListedMember = ({
  String file,
  int line,
  String type,
  String member,
  bool bodiless,
});

/// The header of a contract listing inside a fenced Dart block.
///
/// Only `abstract class` qualifies, because only there does a bare declaration
/// *mean* anything: a concrete class cannot hold an abstract member, so a bare
/// declaration in a listing of one is unambiguously a body left out for
/// brevity. Reading those as claims would fail every concrete-class listing in
/// `doc/` for saying something it never said.
final RegExp _listingHeader = RegExp(r'^abstract class ([A-Za-z_]\w*)');

/// Listings that describe *application* code rather than this package's.
///
/// `doc/audit.md` shows an invented `AdminApi` to demonstrate that
/// `@TomAudited` on a method audits the invocation; nothing in `lib/` declares
/// it, and nothing should. Naming the exemption rather than skipping every
/// unresolvable class keeps the reach check able to say what it is for: a
/// listing whose class has quietly been renamed still fails, because the
/// rename produces a name that is not on this list.
const Set<String> _illustrativeListings = {'AdminApi'};

/// A member declaration that cannot be abstract whatever its shape.
///
/// A `static` is never abstract, and neither is a constructor — a bodiless
/// `TomTypedPersistenceBase(this.types);` still constructs, and the source's
/// having a body there says nothing a subclass must act on. Comparing either
/// would report a difference that is not a defect.
bool _cannotBeAbstract(String line, String type) {
  final head = line.trimLeft();
  if (RegExp(r'^(?:@\w+\s+)*static\b').hasMatch(head)) return true;
  return RegExp('^(?:const |factory )*$type\\s*[.(]').hasMatch(head);
}

/// Every member of every contract listing in the module documents.
List<_ListedMember> _listedMembers() => Directory('doc')
    .listSync()
    .whereType<File>()
    .where((entry) => entry.path.endsWith('.md'))
    .expand(
      (file) =>
          _listedMembersOf(file.uri.pathSegments.last, file.readAsLinesSync()),
    )
    .toList();

/// The contract-listing members of one document, reported under [file].
///
/// Split from [_listedMembers] so the line handling can be exercised on a
/// listing written for the purpose. Its rules are individually small and
/// jointly not obvious — which fence counts, where a listing ends, what resets
/// the current class — and each of them, when wrong, changes *which class a
/// member is attributed to* rather than producing an error.
List<_ListedMember> _listedMembersOf(String file, List<String> lines) {
  final found = <_ListedMember>[];
  var inDart = false;
  String? current;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith('```')) {
      inDart = line.startsWith('```dart');
      current = null;
      continue;
    }
    if (!inDart) continue;

    final header = _listingHeader.firstMatch(line);
    if (header != null) {
      current = header.group(1);
      continue;
    }
    // A `}` at column zero closes the listing; anything else at column zero is
    // a sibling declaration, and either way the members have ended. Without
    // this the members of a concrete class declared later in the same fence —
    // `doc/audit.md` puts one right before its listing — are read as members
    // of the abstract class above, and are then compared against a class that
    // never declared them.
    if (line.isNotEmpty && !line.startsWith(' ')) {
      current = null;
      continue;
    }
    if (current == null) continue;
    if (_cannotBeAbstract(line, current)) continue;

    final member = _memberNameOf(line);
    if (member == null) continue;
    found.add((
      file: file,
      line: i + 1,
      type: current,
      member: member,
      bodiless: _endsWithoutBody(lines, i),
    ));
  }
  return found;
}

/// The modules whose Overview table has not been reconciled against its
/// exports yet — quest todo `tcincb3_ahwn`.
///
/// A quarantine rather than an opt-in list, so that the default for a *new*
/// module is checked. The debt is deliberately spent as a visible skip on every
/// run: the trap this file exists to close is an invariant nobody was looking
/// at, and a list of modules silently exempted from the check would be the same
/// trap wearing the check's clothes.
const Set<String> _tablesPendingReconciliation = {
  'authentication',
  'configuration',
  'datasources',
  'db_migration',
  'endpoints',
  'export',
  'file_storage',
  'little_things',
  'object_persistence',
  'preferences',
  'scheduling',
};

void main() {
  group('doc/api_reference mirrors lib/src/tomserver', () {
    test('every module has an API summary', () {
      final modules = _modules();
      final summaries = _docs(
        'doc/api_reference',
        stripPrefix: 'api_summary_',
      ).where((name) => name != 'index').toList();

      final missing = modules.where((m) => !summaries.contains(m)).toList();
      expect(
        missing,
        isEmpty,
        reason:
            'These modules have no doc/api_reference/api_summary_<module>.md: '
            '${missing.join(', ')}. Add one following the structure the other '
            'summaries use and list it in api_summary_index.md.',
      );
    });

    test('every API summary has a module', () {
      final modules = _modules();
      final summaries = _docs(
        'doc/api_reference',
        stripPrefix: 'api_summary_',
      ).where((name) => name != 'index').toList();

      final orphaned = summaries.where((s) => !modules.contains(s)).toList();
      expect(
        orphaned,
        isEmpty,
        reason:
            'These API summaries document no module under lib/src/tomserver/: '
            '${orphaned.join(', ')}. Delete the summary, or rename it if the '
            'module was renamed.',
      );
    });

    test('every module has a narrative guide', () {
      final modules = _modules();
      final guides = _docs('doc');

      final missing = modules.where((m) => !guides.contains(m)).toList();
      expect(
        missing,
        isEmpty,
        reason:
            'These modules have no doc/<module>.md guide: '
            '${missing.join(', ')}. The summary lists the API; the guide '
            'explains what it is for, and both are expected.',
      );
    });

    test('the index links every API summary', () {
      final index = File(
        'doc/api_reference/api_summary_index.md',
      ).readAsStringSync();
      final summaries = _docs(
        'doc/api_reference',
        stripPrefix: 'api_summary_',
      ).where((name) => name != 'index').toList();

      final unlisted = summaries
          .where((s) => !index.contains('api_summary_$s.md'))
          .toList();
      expect(
        unlisted,
        isEmpty,
        reason:
            'api_summary_index.md does not link these summaries: '
            '${unlisted.join(', ')}. An index that omits part of the package '
            'reads as complete, so an unlisted summary is an invisible one.',
      );
    });
  });

  group('each guide\'s Overview table lists the module\'s exported types', () {
    for (final module in _modules()) {
      final table = _overviewTableTypes(module);
      if (table == null) continue;

      test(
        module,
        () {
          final exported = _exportedTypes(module);

          final missing = exported.where((t) => !table.contains(t)).toList();
          expect(
            missing,
            isEmpty,
            reason:
                'doc/$module.md\'s Overview table does not list these exported '
                'types: ${missing.join(', ')}. The table is headed "Type", so a '
                'reader takes it for the module\'s surface and concludes an '
                'unlisted type does not exist.',
          );

          final orphaned = table.where((t) => !exported.contains(t)).toList();
          expect(
            orphaned,
            isEmpty,
            reason:
                'doc/$module.md\'s Overview table names these types, which the '
                'barrel does not export from $module: ${orphaned.join(', ')}. '
                'Either the type was renamed or removed, or it belongs to '
                'another module\'s table.',
          );
        },
        skip: _tablesPendingReconciliation.contains(module)
            ? 'Overview table not reconciled yet — quest todo tcincb3_ahwn.'
            : null,
      );
    }

    test('every quarantined module still has a table to reconcile', () {
      final stale = _tablesPendingReconciliation
          .where((module) => _overviewTableTypes(module) == null)
          .toList();
      expect(
        stale,
        isEmpty,
        reason:
            'These modules are quarantined but have no Overview table: '
            '${stale.join(', ')}. A quarantine entry that names nothing '
            'suppresses no check and reads as outstanding debt that is not, '
            'so remove it.',
      );
    });
  });

  group('the configuration summary lists every configurable field', () {
    const module = 'configuration';
    const className = 'TomBaseServerConfiguration';
    const path = 'lib/src/tomserver/$module/base_server_configuration.dart';

    test('the census recovers both sides', () {
      // Neither side may come back empty, or the two comparisons below would
      // pass by finding nothing to disagree about.
      expect(
        _declaredFields(path, className),
        isNotEmpty,
        reason: 'no field declarations were recovered from $path',
      );
      expect(
        _summaryProperties(module, className),
        isNotEmpty,
        reason:
            'no Properties table was found under "### $className" in '
            'doc/api_reference/api_summary_configuration.md',
      );
    });

    test('every declared field has a row', () {
      final documented = _summaryProperties(module, className);
      final missing = _declaredFields(
        path,
        className,
      ).where((field) => !documented.contains(field)).toList();
      expect(
        missing,
        isEmpty,
        reason:
            'api_summary_configuration.md\'s Properties table for $className '
            'omits these fields: ${missing.join(', ')}. Every field on this '
            'class is a deployment-facing setting, and one that is absent from '
            'the table is invisible to the operator who needed to set it.',
      );
    });

    test('every row has a declared field', () {
      final declared = _declaredFields(path, className);
      final orphaned = _summaryProperties(
        'configuration',
        className,
      ).where((property) => !declared.contains(property)).toList();
      expect(
        orphaned,
        isEmpty,
        reason:
            'api_summary_configuration.md\'s Properties table for $className '
            'lists these, which the class no longer declares: '
            '${orphaned.join(', ')}. A row for a removed field is worse than a '
            'missing one, because it reads as a setting that can be supplied.',
      );
    });

    test('the rows are in source order', () {
      // The table is a mirror, so the reader can hold it beside the class. Kept
      // in source order it stays diffable against the declarations, and a field
      // inserted mid-block lands in the table where it lands in the source
      // rather than at the end.
      expect(
        _summaryProperties(module, className),
        _declaredFields(path, className),
        reason:
            'the Properties table for $className is complete but reordered; '
            'keep it in declaration order so the two can be read side by side.',
      );
    });
  });

  group('the configuration guide explains every deployment setting', () {
    const className = 'TomBaseServerConfiguration';
    const path =
        'lib/src/tomserver/configuration/base_server_configuration.dart';

    List<String> declared() =>
        _declaredFields(path, className).where(_isDeploymentSetting).toList();

    test('the census recovers both sides', () {
      // Each block is asserted separately rather than the total: the guard
      // matches block membership by name prefix, so a block renamed wholesale
      // would otherwise vanish from *both* sides at once and the comparisons
      // below would agree about nothing.
      final fields = declared();
      expect(
        fields.where((field) => field.startsWith('serviceAccount')),
        isNotEmpty,
        reason: 'no self-login settings were recovered from $path',
      );
      expect(
        fields.where((field) => field.startsWith('smtp')),
        isNotEmpty,
        reason: 'no SMTP settings were recovered from $path',
      );
      expect(
        fields.where((field) => field.startsWith('sms')),
        isNotEmpty,
        reason: 'no SMS settings were recovered from $path',
      );

      final (documented, _) = _guideDeploymentSettings();
      expect(
        documented,
        isNotEmpty,
        reason:
            'no setting rows were found under "## Deployment Settings" in '
            'doc/configuration.md',
      );
      expect(
        _secretBearingFields(path, className),
        isNotEmpty,
        reason:
            'no field on $className is marked secret-bearing in its dartdoc; '
            'the guide derives its secret markings from those, so losing the '
            'marker would silently empty the check below',
      );
    });

    test('every deployment setting has a row', () {
      final (documented, _) = _guideDeploymentSettings();
      final missing = declared()
          .where((field) => !documented.contains(field))
          .toList();
      expect(
        missing,
        isEmpty,
        reason:
            'doc/configuration.md\'s "Deployment Settings" section says '
            'nothing about: ${missing.join(', ')}. These settings are filled '
            'in by an operator reading this guide, and one the guide never '
            'names cannot be set by someone who did not already know it '
            'existed.',
      );
    });

    test('every row names a deployment setting', () {
      final declaredFields = _declaredFields(path, className);
      final (documented, _) = _guideDeploymentSettings();
      final orphaned = documented
          .where((setting) => !declaredFields.contains(setting))
          .toList();
      expect(
        orphaned,
        isEmpty,
        reason:
            'doc/configuration.md\'s "Deployment Settings" section documents '
            'these, which $className no longer declares: '
            '${orphaned.join(', ')}. A row for a removed setting reads as an '
            'instruction to supply a key that nothing will ever read.',
      );
    });

    test('the rows are in source order', () {
      final (documented, _) = _guideDeploymentSettings();
      expect(
        documented,
        declared(),
        reason:
            'the "Deployment Settings" tables are complete but reordered. The '
            'three blocks are contiguous in the class, and keeping the tables '
            'in declaration order is what lets a reviewer diff them against '
            'the source rather than sort both by hand.',
      );
    });

    test('every secret-bearing setting is marked as one', () {
      final (_, marked) = _guideDeploymentSettings();
      expect(
        marked,
        _secretBearingFields(path, className).toSet(),
        reason:
            'the settings doc/configuration.md marks **Secret-bearing** and '
            'the ones whose dartdoc says so have drifted apart. A secret left '
            'unmarked is the dangerous direction — it invites someone to '
            'author the value into a spec or a checked-in configuration tree '
            'instead of supplying it out of band — but a value marked secret '
            'that is not one is checked too, because a marker that is '
            'sometimes wrong stops being read.',
      );
    });
  });

  group('every summary files a member under the class that declares it', () {
    test('mapGroupedRow belongs to the data source, not the statement', () {
      // The specific misfiling this group was written for, pinned by name. It
      // is a static of the driver that a grouped *statement* carries the
      // projection for, so "which class is this about" and "which class is
      // this on" give different answers — and the documents answered the
      // first question while appearing to answer the second.
      expect(
        _resolveMember('MariaDbDatasource', 'mapGroupedRow'),
        isTrue,
        reason:
            'mapGroupedRow is no longer declared on MariaDbDatasource. If it '
            'moved, move its row in api_summary_datasources.md with it.',
      );
      expect(
        _resolveMember('MariadbPreparedStatement', 'mapGroupedRow'),
        isFalse,
        reason:
            'MariadbPreparedStatement now resolves mapGroupedRow, so the two '
            'documents that disagreed about its owner can no longer be told '
            'apart by this test.',
      );
    });

    test('every documented member is declared on the class it sits under', () {
      final misfiled = <String>[];
      for (final row in _attributions()) {
        if (_resolveMember(row.type, row.member) == false) {
          misfiled.add('${row.file}:${row.line} ${row.type}.${row.member}');
        }
      }
      expect(
        misfiled,
        isEmpty,
        reason:
            'These rows are filed under a class that does not declare or '
            'inherit them:\n  ${misfiled.join('\n  ')}\nA summary section is a '
            'claim of ownership, so a row under the wrong heading tells a '
            'reader to call a member on a class that has none.',
      );
    });

    test('the sweep reaches the summaries it polices', () {
      // Every assertion above passes vacuously on a census that recovered
      // nothing — an empty parse reports no misfilings at all. These floors
      // are the difference between "checked and clean" and "not checked", and
      // they are floors rather than exact counts so that adding a class or a
      // row does not fail a test about coverage.
      expect(
        _declarations.length,
        greaterThan(300),
        reason:
            'only ${_declarations.length} types were recovered from '
            'lib/src/tomserver; the parser has stopped reading the package',
      );

      final rows = _attributions();
      expect(
        rows.length,
        greaterThan(1500),
        reason:
            'only ${rows.length} member rows were recovered from '
            'doc/api_reference; the summaries are no longer being read',
      );

      final undecidable = rows
          .where((row) => _resolveMember(row.type, row.member) == null)
          .toList();
      expect(
        undecidable.length / rows.length,
        lessThan(0.02),
        reason:
            '${undecidable.length} of ${rows.length} rows cannot be decided '
            'because an ancestor is declared outside this package. '
            'Undecidable rows are not checked, so a large share of them is a '
            'hole in the guard rather than a property of the documents.',
      );

      // Named because they are the two sections the misfiling moved between,
      // and because a generic class heading carries its type parameters — the
      // shape that silently excluded twenty-one classes.
      for (final type in const [
        'MariaDbDatasource',
        'MariadbPreparedStatement',
      ]) {
        expect(
          rows.where((row) => row.type == type),
          isNotEmpty,
          reason:
              'no rows were attributed to $type, so the section holding '
              'the misfiled static is not being read at all',
        );
      }
    });

    test('the parser reads the declaration shapes that defeated it', () {
      // Each of these silently broke the census while it was being written:
      // the member came back wrong or not at all, and the effect was a class
      // whose members went unseen — which reads as "documented member not
      // declared" and would have been mistaken for a documentation bug. They
      // are pinned here so a change to the parser fails loudly instead.
      expect(
        _memberNameOf('  static (String, List<String>) toPositional(String s)'),
        'toPositional',
        reason: 'a record return type must not make `static (` read as a call',
      );
      expect(
        _memberNameOf('  final DateTime Function() clock;'),
        'clock',
        reason: 'a function-typed field is a field, not a method `Function`',
      );
      expect(
        _memberNameOf('  Future<TomLease?> acquire(String r) async {'),
        'acquire',
        reason: 'an async body must not make `async` read as the member name',
      );
      expect(
        _memberNameOf('  static ({String sentence}) referenceQuery(int a) {'),
        'referenceQuery',
        reason: 'a record return type brace is not the start of the body',
      );
      expect(
        _memberNameOf('  Set<Type> get registeredTypes {'),
        'registeredTypes',
        reason: 'a block-bodied getter declares a member',
      );
      expect(
        _memberNameOf('  static String globalSettingKey ='),
        'globalSettingKey',
        reason: 'an initialiser continued on the next line still declares one',
      );
      expect(
        _withoutTypeArguments(
          'class Prepared<T extends Object> extends TomPrepared<T> {',
        ),
        'class Prepared extends TomPrepared {',
        reason:
            'the bound in a type parameter must not be read as a supertype, '
            'which would make every lookup on the class undecidable',
      );
    });
  });

  group('every contract listing agrees with source on what is abstract', () {
    test('a transport is told which members it actually has to write', () {
      // The three that were documented as demands and are in fact gifts. The
      // two `supports…` defaults are `false` on purpose — a transport that has
      // not considered attachments cannot carry them — so a document that
      // presents them as abstract hides the safe answer behind a chore.
      final transport = _declarations['TomMessageTransport']!;
      for (final member in ['supportsCopies', 'supportsAttachments', 'close']) {
        expect(
          transport.bodilessMembers,
          isNot(contains(member)),
          reason: '$member has a default in source',
        );
      }
      // The two that genuinely are demands, pinned so the fix above cannot be
      // "mark everything concrete and move on".
      expect(transport.bodilessMembers, containsAll(['channel', 'send']));
    });

    test('no listing presents an inherited member as one to implement', () {
      // The cost of getting this backwards runs both ways. A concrete member
      // shown bare is work invented for the reader — they implement what they
      // already had, and their override silently replaces a default that was
      // load-bearing. An abstract member shown with a body is worse: it reads
      // as optional, so it is skipped, and the class does not compile.
      final offenders = <String>[];
      for (final listed in _listedMembers()) {
        final declaration = _declarations[listed.type];
        // A class invented for the document has no source to disagree with,
        // and a member the listing shows but the class inherits is not this
        // check's business. Anything else unresolvable is a rename, which the
        // reach test below reports rather than swallowing here.
        if (declaration == null) continue;
        if (!declaration.members.contains(listed.member)) continue;
        final inSource = declaration.bodilessMembers.contains(listed.member);
        if (inSource == listed.bodiless) continue;
        offenders.add(
          '${listed.file}:${listed.line} ${listed.type}.${listed.member} '
          'documented as ${listed.bodiless ? "abstract" : "concrete"}, '
          'source is ${inSource ? "abstract" : "concrete"}',
        );
      }
      expect(offenders, isEmpty);
    });

    test('the sweep reaches the listings it is meant to police', () {
      final listed = _listedMembers();
      final resolved = listed
          .where(
            (m) => _declarations[m.type]?.members.contains(m.member) ?? false,
          )
          .toList();

      // Without a floor, the check above passes just as happily on a parser
      // that stopped finding listings at all — and it has failed that way
      // before, from a wrapped header and from an escaped generic.
      expect(resolved.length, greaterThan(25));
      expect(
        resolved.map((m) => m.type).toSet(),
        containsAll([
          'TomMessageTransport',
          'TomTransactionParticipant',
          'TomTabularRenderer',
          'TomExportStore',
        ]),
      );
      // Both shapes have to be present, or the comparison is only ever making
      // one of its two possible mistakes visible.
      expect(resolved.any((m) => m.bodiless), isTrue);
      expect(resolved.any((m) => !m.bodiless), isTrue);
      // Every class named by a listing is one the package declares, save the
      // few named as illustrations. Without this the sweep's `continue` on an
      // unresolvable class is indistinguishable from silence: a listing whose
      // class was renamed would be skipped rather than reported.
      final unknown = listed
          .map((m) => m.type)
          .toSet()
          .where((type) => !_declarations.containsKey(type))
          .where((type) => !_illustrativeListings.contains(type))
          .toSet();
      expect(unknown, isEmpty);
    });

    test('the parser reads the declaration shapes a listing uses', () {
      // Bodiless: the declaration ends at a `;`, on this line or a later one.
      expect(_endsWithoutBody(['  Future<void> close();'], 0), isTrue);
      expect(
        _endsWithoutBody([
          '  Future<TomPreparedStatement<T>> prepareStatement<T extends '
              'Object>(',
          '    TomQuery query, [',
          '    Type? resultType,',
          '  ]);',
        ], 0),
        isTrue,
        reason: 'a wrapped parameter list must not read as an abstract member',
      );
      // Bodied, in each spelling a listing uses.
      expect(
        _endsWithoutBody(['  bool get supportsCopies => false;'], 0),
        isFalse,
      );
      expect(_endsWithoutBody(['  Future<void> close() async {}'], 0), isFalse);
      expect(
        _endsWithoutBody(['  String indent(int i) { … }'], 0),
        isFalse,
        reason: 'an elided body is still a body',
      );
      expect(
        _endsWithoutBody(['  final List<int> _rows = [];'], 0),
        isFalse,
        reason: 'an initialiser ends the declaration as surely as a body',
      );
      expect(
        _endsWithoutBody(['  int retriesFor({int limit = 3}) => limit;'], 0),
        isFalse,
        reason: 'a default inside a parameter list is not the declaration end',
      );
      // The members no shape comparison applies to.
      expect(
        _cannotBeAbstract('  static Tom2FAPolicy resolve();', 'Tom2FAPolicy'),
        isTrue,
      );
      expect(
        _cannotBeAbstract(
          '  TomTypedPersistenceBase(this.types);',
          'TomTypedPersistenceBase',
        ),
        isTrue,
        reason: 'a bodiless constructor still constructs',
      );
      expect(
        _cannotBeAbstract(
          '  const TomFrameworkKey.unique(this.suffix);',
          'TomFrameworkKey',
        ),
        isTrue,
        reason: 'a named constructor is a constructor',
      );
      expect(
        _cannotBeAbstract('  Future<void> close();', 'TomMessageTransport'),
        isFalse,
      );
      // A trailing comment is the annotation style contract listings use, and
      // it is the *bodiless* members that carry one — `TomMessageTransport`
      // and `TomTransactionParticipant` both gloss theirs that way. Reading
      // the comment as the member excuses exactly those members from the
      // comparison, so the stripping is pinned rather than assumed.
      expect(
        _memberNameOf('  bool get supportsCopies;        // Cc / Bcc'),
        'supportsCopies',
      );
      expect(
        _withoutLineComment("  final Uri base = Uri.parse('http://a/b');"),
        "  final Uri base = Uri.parse('http://a/b');",
        reason: 'a `//` inside a string is not a comment',
      );
    });

    test('a listing ends where the document stops describing it', () {
      // Every way a listing can end, in one document. Getting any of them
      // wrong misattributes rather than fails: the members of whatever came
      // next are compared against the class above them, so the report names a
      // class the reader never wrote and the real disagreement goes unseen.
      final members = _listedMembersOf('synthetic.md', [
        'Prose naming `abstract class TomDecoy { }` outside a fence.',
        '',
        '```dart',
        'abstract class TomContract {',
        '  Future<void> demanded();',
        '}',
        '',
        'class TomConcrete {',
        '  void notPartOfTheContract() {}',
        '}',
        '```',
        '',
        '```yaml',
        'abstract class TomNotDart {',
        '  void ignored();',
        '}',
        '```',
      ]);

      expect(members.map((m) => '${m.type}.${m.member}'), [
        'TomContract.demanded',
      ]);
      expect(members.single.line, 5);
      expect(members.single.bodiless, isTrue);
    });
  });
}
