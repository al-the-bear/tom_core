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
}
