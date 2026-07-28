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
/// Everything here reads the working tree, so the failure names the missing
/// file and appears the moment the sixth module lands without one.
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
        .map((entry) => entry.uri.pathSegments[entry.uri.pathSegments.length - 2])
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
}
