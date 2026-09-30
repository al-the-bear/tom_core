// REPO-WIDE GUARD (tom_core_kernel) — no package in tom_ai/core resolves a
// tom_* version behind one already in the pub cache.
//
// This is the tom_ai/core repo's own copy of the d4rt repo's
// `tom_d4rt_ast/test/scc45_resolution_guard_test.dart`, which is the model and
// carries the full history of the defect family; the ai_build repo carries the
// same copy (`tom_specs_clitool/test/scc45_resolution_guard_test.dart`), which
// this one follows. What follows states only what this copy needs to be read
// on its own.
//
// WHY A FROZEN LOCK MATTERS. `dart pub get` is LOCK-PRESERVING: a lower-bound
// constraint admits every newer release without ever selecting one once a lock
// exists. `pubspec.lock` is gitignored, so the staleness is per-machine and
// invisible in any diff — two hosts run the same suite against different
// dependency sets and nothing records which. A suite green against a frozen
// lock certifies a version nobody installs.
//
// WHAT THIS REPO HAD, measured 2026-09-30 and cleared by the sweep that added
// this file: 37 frozen resolutions across 15 packages — the widest spread in
// the workspace, nearly one finding per package, which is the signature of a
// repo nothing had re-resolved in months. The worst were `tom_core_kernel` and
// `tom_core_server`, the framework's load-bearing packages, resolving
// `tom_d4rt` 1.11.0 while 1.210.0 was cached. `pub upgrade` in all 23 locked
// packages moved every one; none was held by a constraint or by unpublished
// sibling work.
//
// WHY IT LIVES HERE. `tom_core_kernel` is the foundation every other package
// in the repo depends on, and its suite is the first `tool/run_suites.py`
// runs; the repo is `publish_to: none`, so a guard that walks sibling packages
// costs no consumer anything. It skips when the repo root is not reachable.
//
// MANY GUARDS, NOT ONE. A single workspace guard would need one exception list
// spanning a dozen repos with no owner; each repo carries its own copy with its
// own owner-named list. `_bin/check_frozen_locks.py tom_ai/core` is the same
// question asked read-only from outside.
//
// ZERO NEW DEPENDENCIES, like the model: the lock is parsed by indentation,
// since it is machine-written and its shape is fixed.
import 'dart:io';

import 'package:test/test.dart';

/// Packages whose presence identifies the tom_ai/core repo root.
const _repoMarkers = ['tom_core_kernel', 'tom_core_server', 'tom_flutter_ui'];

/// Only this workspace's own packages: a third-party dependency cannot suffer
/// an unpropagated publish from here.
const _ownedPrefix = 'tom_';

/// Packages exempted from FL-2, each with the reason it is frozen and who will
/// unfreeze it. AN EXCEPTION WITHOUT AN OWNER IS A LEAK: if you add one and
/// cannot name who unfreezes it, find that out first.
///
/// EMPTY, and that is the intended resting state — FL-3 deletes any entry
/// that stops describing a frozen lock. Keep the map rather than removing it:
/// re-deriving the shape under time pressure is how an exemption gets added
/// without an owner.
const Map<String, String> _frozenLockExceptions = <String, String>{};

/// Below this many distinct cached `tom_*` packages, a pass means nothing: the
/// discriminator can only see a freeze whose newer version is cached here.
const int _minimumCachedPackages = 5;

class _Resolution {
  const _Resolution(this.name, this.source, this.version, this.dependency);
  final String name;
  final String source;
  final String version;

  /// The lock's own classification: `direct main`, `direct dev`, `direct
  /// overridden` or `transitive`.
  final String dependency;

  bool get isDirect => dependency.startsWith('direct');
}

Directory? _repoRoot() {
  var dir = Directory.current.absolute;
  for (var i = 0; i < 6; i++) {
    if (_repoMarkers.every((p) => Directory('${dir.path}/$p').existsSync())) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

/// Directories whose packages are nobody's to upgrade: build output, and the
/// untracked scratch the gates write under `tool/ztmp/` and the suites under
/// `testlog/` — machine state, regenerated on demand, never a package a reader
/// resolves.
bool _pruned(Directory dir) {
  final name = dir.path.split(Platform.pathSeparator).last;
  return name.startsWith('.') ||
      name == 'build' ||
      name == 'node_modules' ||
      name == 'ztmp' ||
      name == 'testlog';
}

/// Every directory under [root] with a pubspec (and, when [locked], a lock).
///
/// Walks nested packages too: a fixture or sample under a package carries its
/// own ignored lock, and a guard that inspected only top-level packages would
/// report green through exactly the case that hides.
List<Directory> _packagesUnder(Directory root, {bool locked = true}) {
  final found = <Directory>[];
  void walk(Directory dir, int depth) {
    if (depth > 5 || _pruned(dir)) return;
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        (!locked || File('${dir.path}/pubspec.lock').existsSync())) {
      found.add(dir);
    }
    for (final child in dir.listSync().whereType<Directory>()) {
      walk(child, depth + 1);
    }
  }

  walk(root, 0);
  return found;
}

List<_Resolution> _lockedTomPackages(Directory package) {
  final lock = File('${package.path}/pubspec.lock');
  if (!lock.existsSync()) return const [];
  final namePattern = RegExp(r'^  ([A-Za-z0-9_]+):\s*$');
  final fieldPattern = RegExp(
    r'^    (dependency|source|version):\s*"?([^"]*)"?\s*$',
  );
  final out = <_Resolution>[];
  String? current, source, version, dependency;
  void flush() {
    if (current != null &&
        current!.startsWith(_ownedPrefix) &&
        source != null &&
        version != null) {
      out.add(_Resolution(current!, source!, version!, dependency ?? ''));
    }
    current = source = version = dependency = null;
  }

  for (final line in lock.readAsLinesSync()) {
    final name = namePattern.firstMatch(line);
    if (name != null) {
      flush();
      current = name.group(1);
      continue;
    }
    final field = fieldPattern.firstMatch(line);
    if (field == null || current == null) continue;
    switch (field.group(1)) {
      case 'source':
        source = field.group(2);
      case 'version':
        version = field.group(2);
      default:
        dependency = field.group(2);
    }
  }
  flush();
  return out;
}

int _compareVersions(String a, String b) {
  List<int> parts(String v) => v
      .split(RegExp(r'[-+]'))
      .first
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final pa = parts(a), pb = parts(b);
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// Pub's own order: `PUB_CACHE` when set and non-empty, then the platform
/// default. The Windows default matters: a guard that looked only at
/// `$HOME/.pub-cache` reports an empty cache there, and so passes blind.
Directory _pubCacheRoot() {
  final explicit = Platform.environment['PUB_CACHE'];
  if (explicit != null && explicit.trim().isNotEmpty) {
    return Directory(explicit);
  }
  if (Platform.isWindows) {
    final local = Platform.environment['LOCALAPPDATA'];
    if (local != null && local.isNotEmpty) {
      return Directory('$local\\Pub\\Cache');
    }
  }
  return Directory('${Platform.environment['HOME'] ?? ''}/.pub-cache');
}

Directory get _hostedCache =>
    Directory('${_pubCacheRoot().path}/hosted/pub.dev');

String? _newestCachedVersion(String name) {
  final dir = _hostedCache;
  if (!dir.existsSync()) return null;
  final prefix = '$name-';
  final stable = dir
      .listSync()
      .whereType<Directory>()
      .map((d) => d.path.split(Platform.pathSeparator).last)
      .where((n) => n.startsWith(prefix))
      .map((n) => n.substring(prefix.length))
      .where((v) => !v.contains('-') && RegExp(r'^\d').hasMatch(v))
      .toList();
  if (stable.isEmpty) return null;
  stable.sort(_compareVersions);
  return stable.last;
}

String _relativeTo(Directory root, Directory dir) =>
    (dir.path.startsWith(root.path)
            ? dir.path.substring(root.path.length + 1)
            : dir.path)
        .replaceAll(r'\', '/');

/// Every lock under [root] resolving a hosted `tom_*` older than the cache
/// holds. THE CACHE IS THE DISCRIMINATOR: comparing against a sibling's pubspec
/// cannot tell a frozen lock from an unpublished sibling, while a newer version
/// sitting in the cache proves pub had it and did not take it.
List<String> _staleLocks(Directory root, Map<String, String> exceptions) {
  final out = <String>[];
  for (final package in _packagesUnder(root)) {
    final rel = _relativeTo(root, package);
    if (exceptions.containsKey(rel.split('/').first)) continue;
    for (final res in _lockedTomPackages(package)) {
      if (res.source != 'hosted') continue;
      final newest = _newestCachedVersion(res.name);
      if (newest != null && _compareVersions(res.version, newest) < 0) {
        out.add(
          '$rel locks ${res.name} ${res.version} while $newest is '
          'already in the pub cache',
        );
      }
    }
  }
  return out;
}

/// Dependency names [package]'s pubspec declares with a `path:` key.
Set<String> _declaredPathDependencies(Directory package) {
  final keyPattern = RegExp(r'^(\s+)([A-Za-z0-9_]+):\s*$');
  final declared = <String>{};
  String? openKey;
  var openIndent = 0;
  for (final raw in File('${package.path}/pubspec.yaml').readAsLinesSync()) {
    final line = raw.split('#').first;
    if (line.trim().isEmpty) continue;
    final indent = line.length - line.trimLeft().length;
    if (openKey != null) {
      if (indent > openIndent) {
        if (line.trimLeft().startsWith('path:')) declared.add(openKey);
        continue;
      }
      openKey = null;
    }
    if (keyPattern.firstMatch(line) case final m?) {
      openKey = m.group(2);
      openIndent = m.group(1)!.length;
    }
  }
  return declared;
}

void main() {
  final root = _repoRoot();

  group('frozen locks (tom_ai/core): resolutions match declarations', () {
    var cachedPackages = 0;

    setUpAll(() {
      final cache = _hostedCache;
      final byPackage = <String, int>{};
      if (cache.existsSync()) {
        for (final entry in cache.listSync().whereType<Directory>()) {
          final dir = entry.path.split(Platform.pathSeparator).last;
          if (!dir.startsWith(_ownedPrefix)) continue;
          final dash = dir.lastIndexOf('-');
          if (dash <= 0) continue;
          byPackage.update(
            dir.substring(0, dash),
            (n) => n + 1,
            ifAbsent: () => 1,
          );
        }
      }
      cachedPackages = byPackage.length;
      // Printed on every run: a pass is a statement about THIS machine's cache,
      // and the number is what makes a green interpretable.
      // ignore: avoid_print
      print(
        '[frozen locks] pub-cache sensitivity: '
        '${byPackage.values.fold(0, (a, b) => a + b)} tom_* version '
        'directories across $cachedPackages packages, '
        '${byPackage.values.where((n) => n > 1).length} holding more than '
        'one version.',
      );
    });

    bool canDiscriminate(String caseName) {
      if (cachedPackages >= _minimumCachedPackages) return true;
      markTestSkipped(
        '$caseName cannot answer on this machine: its pub cache '
        'holds $cachedPackages distinct tom_* package(s), below the '
        '$_minimumCachedPackages needed to tell a frozen lock from a current '
        'one. A pass here would be indistinguishable from a clean repo.',
      );
      return false;
    }

    test('FL-1: no undeclared path resolution', () {
      if (root == null) {
        markTestSkipped(
          'tom_ai/core repo root not reachable — nothing to check',
        );
        return;
      }
      final offenders = <String>[];
      for (final package in _packagesUnder(root)) {
        // An overrides file is a declaration too.
        if (File('${package.path}/pubspec_overrides.yaml').existsSync()) {
          continue;
        }
        final declared = _declaredPathDependencies(package);
        for (final res in _lockedTomPackages(package)) {
          // DIRECT only, as in the ai_build copy: a transitive source is decided
          // by the dependency that declares it, and here every framework package
          // path-links its siblings, so a sample's lock resolves several
          // `tom_core_*` packages from path through them without naming any.
          // The defect it catches — a declaration dropped while the lock keeps
          // resolving the path — is always a DIRECT dependency, and that is what
          // this asks.
          if (!res.isDirect) continue;
          if (res.source == 'path' && !declared.contains(res.name)) {
            offenders.add(
              '${_relativeTo(root, package)} resolves ${res.name} '
              'from path (${res.version}) but declares no path dependency',
            );
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'These test against a local working tree while their '
            'pubspec advertises a published version. Run `pub get` in each; '
            'pub discards a path resolution the pubspec no longer declares.\n'
            '${offenders.join('\n')}',
      );
    });

    test('FL-2: no lock is behind a version already in the pub cache', () {
      if (root == null) {
        markTestSkipped(
          'tom_ai/core repo root not reachable — nothing to check',
        );
        return;
      }
      if (!canDiscriminate('FL-2')) return;
      final offenders = _staleLocks(root, _frozenLockExceptions);
      expect(
        offenders,
        isEmpty,
        reason:
            '`pub get` is lock-preserving, so these locks were passed '
            'over by a resolution that had the newer version on hand.\n'
            'REMEDY: `dart pub upgrade` (or `flutter pub upgrade`) in each '
            'package, AND in every nested sample or fixture under it; then '
            'run the suite. If an upgrade does NOT move a version, the cause '
            'is the other one — a constraint holding it, or unpublished work '
            'in the sibling working tree — and the fix is to raise or '
            'publish, not to re-resolve.\n${offenders.join('\n')}',
      );
    });

    test('FL-3: every exception is still load-bearing', () {
      if (root == null) {
        markTestSkipped(
          'tom_ai/core repo root not reachable — nothing to check',
        );
        return;
      }
      // Measured with NO exceptions applied: the question is which packages
      // are still frozen, and the exception list would hide exactly those.
      final stillFrozen = _staleLocks(
        root,
        const {},
      ).map((line) => line.split(' ').first.split('/').first).toSet();
      final obsolete = _frozenLockExceptions.keys.toSet().difference(
        stillFrozen,
      );
      expect(
        obsolete,
        isEmpty,
        reason:
            'Exempted but no longer frozen — the exemption now grants '
            'only the right to freeze again unnoticed. Delete: '
            '${obsolete.join(', ')}',
      );
    });
  });
}
