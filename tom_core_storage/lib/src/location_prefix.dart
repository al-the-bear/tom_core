/// The one rule by which a setting keyed by storage location applies to a
/// folder: the longest location that is the folder or one of its ancestors.
///
/// Shared by every location-keyed settings group — `collaboration` and the folder layer of the `ai` group — so the two cannot
/// disagree about which rule covers a folder.
///
/// **Matched on a path boundary.** A plain `startsWith` read a rule on
/// `github:o/r/team` as covering `github:o/r/teammates`, which is a different
/// folder; for a consent setting that is a rule applied where nobody set it.
/// A location covers a folder when they are equal, or when the folder
/// continues the location at a `/` — or at a `\`, which is where a Windows
/// path continues, and which a `github:` locator never contains. A location
/// that itself ends in a separator or `:` (a scheme root, `github:`) already
/// ends on a boundary.
library;

/// The value [map] holds for the longest location covering [folder], or null
/// when none does.
T? tomLongestLocationPrefix<T>(Map<String, T> map, String folder) {
  String? best;
  for (final location in map.keys) {
    if (!tomLocationCovers(location, folder)) continue;
    if (best == null || location.length > best.length) best = location;
  }
  return best == null ? null : map[best];
}

/// Whether a rule on [location] applies to [folder].
bool tomLocationCovers(String location, String folder) {
  if (location.isEmpty || !folder.startsWith(location)) return false;
  if (folder.length == location.length) return true;
  if (location.endsWith('/') ||
      location.endsWith(r'\') ||
      location.endsWith(':')) {
    return true;
  }
  final next = folder[location.length];
  return next == '/' || next == r'\';
}
