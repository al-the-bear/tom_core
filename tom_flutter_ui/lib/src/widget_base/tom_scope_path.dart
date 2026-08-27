import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Builds canonical resource paths from a [TomScope] and a widget id.
///
/// A resource path is `<scopePath>.<tomId>`, with the separator dropped when
/// the scope path is empty — a widget at the root addresses its resources by
/// its bare id, not by `.id`. That is the whole rule, and every path in the
/// library goes through it: resource lookups, authorization lookups and group
/// registration all address the same tree, so a widget that composed its path
/// differently from its neighbours would read a bundle belonging to something
/// else while still rendering perfectly.
///
/// This class holds no Flutter dependency by design. It sits below
/// [TomNodeBase], which every widget extends and which needs the path in its
/// initialiser list — so the rule cannot live in `TomCtr`, whose resource
/// accessors pull in the widget layer. [TomCtr.resolvePath] forwards here.
///
/// The three entry points differ only in what the caller already holds:
///
/// | Method     | Parent          | Id       | Returns   |
/// | ---------- | --------------- | -------- | --------- |
/// | [join]     | `String`        | `String` | `String`  |
/// | [qualify]  | `TomScope?`     | `String` | `String`  |
/// | [resolve]  | `TomScope?`     | `String?`| `String?` |
///
/// [join] is the rule; the other two resolve a scope down to its path and hand
/// it over, so there is exactly one place a change to the composition lands.
class TomScopePath {
  TomScopePath._();

  /// Joins [parentPath] and [tomId] into a resource path.
  ///
  /// Use this when the parent is already a path string rather than a scope —
  /// a form field derives its base path from its form's `basePath`, which is
  /// itself a resolved path and not a [TomScope].
  static String join(String parentPath, String tomId) =>
      parentPath.isEmpty ? tomId : '$parentPath.$tomId';

  /// Qualifies [tomId] with the path of [scope], or of [TomScope.current] when
  /// no scope is given.
  static String qualify(String tomId, [TomScope? scope]) =>
      join((scope ?? TomScope.current).getScopePath(), tomId);

  /// Qualifies [tomId] the way [qualify] does, or returns `null` when [tomId]
  /// is `null`.
  ///
  /// A widget whose id is optional has no resource path at all when it has no
  /// id — `null` here means "addresses nothing", which is what makes the
  /// resource accessors return their defaults rather than look up the empty
  /// path.
  static String? resolve(String? tomId, [TomScope? scope]) =>
      tomId == null ? null : qualify(tomId, scope);
}
