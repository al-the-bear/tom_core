/// Making the filesystem refuse, for the tests that need an I/O failure.
///
/// A store's read and delete failure paths have no in-process trigger: the only
/// honest way to reach them is to take the permission away and ask again. That
/// works on a POSIX filesystem as an ordinary user and nowhere else, so the
/// suites that use it need to know *whether it worked* rather than assume it —
/// hence [chmodIsIneffective], which finds out once per process.
///
/// It lives here rather than in either suite because both the export and the
/// file-storage backends are directory-backed and both need the same probe;
/// a second copy would be a second thing to keep true.
library;

import 'dart:io';

/// Whether `chmod` cannot be relied on to deny this process access.
///
/// The store's I/O failure paths are only reachable by making the filesystem
/// refuse — which Windows has no `chmod` for, and which root ignores. Probing
/// once, rather than assuming, keeps the tests honest: they run where they can
/// prove something and say why they did not where they cannot.
final bool chmodIsIneffective = () {
  if (Platform.isWindows) return true;
  final probe = File(
    '${Directory.systemTemp.createTempSync('tom_chmod_').path}/p',
  )..writeAsStringSync('x');
  Process.runSync('chmod', ['000', probe.path]);
  try {
    probe.readAsBytesSync();
    return true; // Read anyway — running as root.
  } on FileSystemException {
    return false;
  } finally {
    Process.runSync('chmod', ['600', probe.path]);
    probe.parent.deleteSync(recursive: true);
  }
}();

/// The reason a permission-dependent test is skipped, or `null` to run it.
///
/// A constant string spelled once, so every skipped case reports the same
/// reason and a reader scanning the output sees one explanation rather than
/// several paraphrases of it.
String? get chmodSkipReason =>
    chmodIsIneffective ? 'needs a non-root POSIX filesystem' : null;
