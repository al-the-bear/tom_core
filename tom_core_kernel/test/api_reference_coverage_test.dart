/// The guard that keeps `doc/` and `doc/api_reference/` a mirror of `lib/`.
///
/// `doc/` claims, by existing, that it documents the package: the README calls
/// it "one folder per module", and `doc/api_reference/` calls itself the
/// per-module API reference. Nothing enforced either claim, and both drifted —
/// `result` and `scheduling` shipped with neither a summary nor (for `result`) a
/// guide, and a `doc/runtime/` folder outlived the module it was written for.
///
/// That was not any one module's omission. Each shipped what its own done-bar
/// asked for; the gap was in an invariant nobody was checking, and an invariant
/// that has already broken in both directions is one that will break again.
///
/// So the invariant is checked here instead of remembered. Three sets must
/// agree, keyed by module directory name:
///
///  * the module directories under `lib/src/tombase/`;
///  * the narrative guides `doc/<module>/`;
///  * the API summaries `doc/api_reference/api_summary_<module>.md`.
///
/// Both directions matter, and the second one matters more. A module without a
/// summary is undocumented, which a reader can at least tell; a summary or guide
/// without a module documents something that no longer exists, and reads as
/// authoritative precisely because it is sitting in a maintained doc tree.
///
/// The last test covers the index: `api_summary_index.md` is the entry point,
/// and an index that omits part of the package reads as complete while being
/// wrong. A summary nobody can navigate to is only marginally better than one
/// that was never written.
///
/// The anchor is `lib/`, never `doc/` — anchoring on the doc tree would make an
/// orphan page invisible, which is the one failure this is here to catch.
///
/// Everything here reads the working tree, so the failure names the missing file
/// and appears the moment the next module lands without one.
library;

import 'dart:io';

import 'package:test/test.dart';

/// Directories under `doc/` that are not module guides.
///
/// `api_reference` is the summaries' own home, not a guide for a module named
/// "api_reference". This is a structural exclusion — it is not, and must not
/// become, a place to park a folder whose module has gone away.
const Set<String> _nonModuleDocDirectories = {'api_reference'};

/// The last path segment of a directory's URI.
String _directoryName(Directory entry) =>
    entry.uri.pathSegments[entry.uri.pathSegments.length - 2];

/// Module directory names under `lib/src/tombase/`, sorted.
///
/// This is the anchor set: it is the code, so it cannot itself be out of date.
List<String> _modules() =>
    Directory('lib/src/tombase').listSync().whereType<Directory>().map(_directoryName).toList()
      ..sort();

/// Names of the per-module guide directories under `doc/`, sorted.
List<String> _guides() =>
    Directory('doc')
        .listSync()
        .whereType<Directory>()
        .map(_directoryName)
        .where((name) => !_nonModuleDocDirectories.contains(name))
        .toList()
      ..sort();

/// Module names of the API summaries under `doc/api_reference/`, sorted.
///
/// The `api_summary_` prefix is stripped so the set comes back keyed by plain
/// module name and compares directly against [_modules]. The index is not a
/// module summary and is dropped.
List<String> _summaries() {
  const prefix = 'api_summary_';
  const suffix = '.md';
  return Directory('doc/api_reference')
      .listSync()
      .whereType<File>()
      .map((entry) => entry.uri.pathSegments.last)
      .where((name) => name.startsWith(prefix) && name.endsWith(suffix))
      .map((name) => name.substring(prefix.length, name.length - suffix.length))
      .where((name) => name != 'index')
      .toList()
    ..sort();
}

void main() {
  group('doc mirrors lib/src/tombase', () {
    test('every module has an API summary', () {
      final missing = _modules().where((m) => !_summaries().contains(m)).toList();

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
      final orphaned = _summaries().where((s) => !modules.contains(s)).toList();

      expect(
        orphaned,
        isEmpty,
        reason:
            'These API summaries document no module under lib/src/tombase/: '
            '${orphaned.join(', ')}. Delete the summary, or rename it if the '
            'module was renamed. If the module moved to another package, the '
            'summary moves with it.',
      );
    });

    test('every module has a narrative guide', () {
      final guides = _guides();
      final missing = _modules().where((m) => !guides.contains(m)).toList();

      expect(
        missing,
        isEmpty,
        reason:
            'These modules have no doc/<module>/ guide folder: '
            '${missing.join(', ')}. The summary lists the API; the guide '
            'explains what it is for, and both are expected.',
      );
    });

    test('every narrative guide has a module', () {
      final modules = _modules();
      final orphaned = _guides().where((g) => !modules.contains(g)).toList();

      expect(
        orphaned,
        isEmpty,
        reason:
            'These doc/<module>/ folders document no module under '
            'lib/src/tombase/: ${orphaned.join(', ')}. A guide for code that is '
            'not here reads as authoritative while describing something the '
            'reader cannot find. Delete it, or move it to the package that owns '
            'the code now.',
      );
    });

    test('the index links every API summary', () {
      final index = File('doc/api_reference/api_summary_index.md').readAsStringSync();
      final unlisted =
          _summaries().where((s) => !index.contains('api_summary_$s.md')).toList();

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
