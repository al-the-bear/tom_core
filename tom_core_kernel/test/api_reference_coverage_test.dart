/// The guard that keeps `doc/`, `doc/api/` and `example/samples/` a
/// mirror of `lib/`.
///
/// `doc/` claims, by existing, that it documents the package: the README calls
/// it "one folder per module", and `doc/api/` calls itself the
/// per-module API reference. Nothing enforced either claim, and both drifted —
/// `result` and `scheduling` shipped with neither a summary nor (for `result`) a
/// guide, and a `doc/runtime/` folder outlived the module it was written for.
///
/// That was not any one module's omission. Each shipped what its own done-bar
/// asked for; the gap was in an invariant nobody was checking, and an invariant
/// that has already broken in both directions is one that will break again.
///
/// So the invariant is checked here instead of remembered. Four sets must
/// agree, keyed by module directory name:
///
///  * the module directories under `lib/src/tombase/`;
///  * the narrative guides `doc/<module>/`;
///  * the API summaries `doc/api/api_summary_<module>.md`;
///  * the sample folders `example/samples/<module>/`.
///
/// The example direction was added after the package was found carrying *two*
/// example trees — a top-level one the README linked and a `example/samples/`
/// one the runner actually executed. They had diverged, and only one of them
/// was ever compiled. A folder no runner imports is a folder nobody discovers
/// has rotted, so the sample checks below assert both membership *and*
/// wiring: the master runner must import every sample folder there is.
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
/// `api` is the summaries' own home, not a guide for a module named
/// "api". This is a structural exclusion — it is not, and must not
/// become, a place to park a folder whose module has gone away.
const Set<String> _nonModuleDocDirectories = {'api'};

/// Sample folders that legitimately have no module under `lib/src/tombase/`.
///
/// `crypto` and `runtime` are re-exported wholesale from `tom_crypto` and
/// `tom_basics`: the kernel's barrel presents them as part of its own surface,
/// so they need samples here, but the code lives in the upstream package and
/// there is no directory for them to mirror. Like `api` above this is
/// a structural exclusion, named one entry at a time — it is not a place to
/// park a sample folder whose module has gone away.
const Set<String> _reExportedSampleFolders = {'crypto', 'runtime'};

/// The last path segment of a directory's URI.
String _directoryName(Directory entry) =>
    entry.uri.pathSegments[entry.uri.pathSegments.length - 2];

/// Module directory names under `lib/src/tombase/`, sorted.
///
/// This is the anchor set: it is the code, so it cannot itself be out of date.
List<String> _modules() => Directory(
  'lib/src/tombase',
).listSync().whereType<Directory>().map(_directoryName).toList()..sort();

/// Names of the per-module guide directories under `doc/`, sorted.
List<String> _guides() =>
    Directory('doc')
        .listSync()
        .whereType<Directory>()
        .map(_directoryName)
        .where((name) => !_nonModuleDocDirectories.contains(name))
        .toList()
      ..sort();

/// Module names of the API summaries under `doc/api/`, sorted.
///
/// The `api_summary_` prefix is stripped so the set comes back keyed by plain
/// module name and compares directly against [_modules]. The index is not a
/// module summary and is dropped.
List<String> _summaries() {
  const prefix = 'api_summary_';
  const suffix = '.md';
  return Directory('doc/api')
      .listSync()
      .whereType<File>()
      .map((entry) => entry.uri.pathSegments.last)
      .where((name) => name.startsWith(prefix) && name.endsWith(suffix))
      .map((name) => name.substring(prefix.length, name.length - suffix.length))
      .where((name) => name != 'index')
      .toList()
    ..sort();
}

/// Names of the sample folders under `example/samples/`, sorted.
List<String> _samples() => Directory(
  'example/samples',
).listSync().whereType<Directory>().map(_directoryName).toList()..sort();

void main() {
  group('doc mirrors lib/src/tombase', () {
    test('every module has an API summary', () {
      final missing = _modules()
          .where((m) => !_summaries().contains(m))
          .toList();

      expect(
        missing,
        isEmpty,
        reason:
            'These modules have no doc/api/api_summary_<module>.md: '
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
      final index = File('doc/api/api_summary_index.md').readAsStringSync();
      final unlisted = _summaries()
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

  group('example/samples mirrors lib/src/tombase', () {
    test('every module has a sample folder', () {
      final samples = _samples();
      final missing = _modules().where((m) => !samples.contains(m)).toList();

      expect(
        missing,
        isEmpty,
        reason:
            'These modules have no example/samples/<module>/ folder: '
            '${missing.join(', ')}. A module with no runnable sample is one a '
            'reader has to learn from the summary alone.',
      );
    });

    test('every sample folder has a module', () {
      final modules = _modules();
      final orphaned = _samples()
          .where(
            (s) =>
                !modules.contains(s) && !_reExportedSampleFolders.contains(s),
          )
          .toList();

      expect(
        orphaned,
        isEmpty,
        reason:
            'These example/samples/<folder>/ folders demonstrate no module '
            'under lib/src/tombase/: ${orphaned.join(', ')}. Delete the folder, '
            'or — if it samples surface this package re-exports from another '
            'one — name it in _reExportedSampleFolders with the reason.',
      );
    });

    test('the master runner imports every sample folder', () {
      final runner = File('example/run_all_samples.dart').readAsStringSync();
      final unwired = _samples()
          .where(
            (s) => !runner.contains(
              "import 'samples/$s/00_run_all_examples.dart'",
            ),
          )
          .toList();

      expect(
        unwired,
        isEmpty,
        reason:
            'example/run_all_samples.dart does not import these sample '
            'folders: ${unwired.join(', ')}. A folder no runner reaches is '
            'never compiled and never executed, so nothing reports when it '
            'stops working — which is exactly how this package ended up with '
            'a second, silently broken example tree.',
      );
    });
  });
}
