import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The surface every Tom widget adds on top of the Flutter widget it wraps.
///
/// A wrapper contributes four things and only four: an identity ([tomId]),
/// the group that identity may belong to ([tomGroup]), the resource path that
/// identity resolves to ([basePath]), and the authorization state that path
/// resolves to ([effectiveAuthState]). Everything else a wrapper does —
/// forwarding parameters, choosing a Flutter concrete, resolving a label — is
/// delegation. This is the part that is *Tom*.
///
/// It is declared here, once, because it used to be declared twice. The kit
/// reaches its widgets down two paths — [TomNodeBase], for the 273 wrappers
/// that extend a family base, and `TomWidgetMixin`, for the 17 whose Flutter
/// original must be a specific subtype to satisfy the parent that accepts it —
/// and each path spelled `basePath` out for itself with no supertype saying
/// the two had to agree. Nothing checked that a wrapper had either, so a
/// wrapper could accept a `tomId`, type-check, read as gated at the call site,
/// and show to everyone. That is not a hypothetical: eight wrappers shipped
/// exactly that defect, and it took a hand-written test naming each of them to
/// find it.
///
/// Naming the contract turns that class of defect into a compile error for new
/// wrappers and into one assertion for existing ones:
/// `test/widgets/widget_conformance_test.dart` enumerates every exported
/// widget, casts it to this type, and checks the four members answer
/// coherently. A wrapper that skips the surface cannot be added to the
/// registry, and one that is missing from the registry fails the suite.
///
/// [TomAuthorizable] (from the kernel) already carried three of the four; the
/// one it cannot carry is [basePath], because path resolution is a Flutter-side
/// concern — it reads the ambient `TomScope`. So this interface is that one
/// addition, not a replacement.
abstract interface class TomWidgetSurface implements TomAuthorizable {
  /// The resolved canonical resource base path for this widget.
  ///
  /// `null` when the widget carries no [tomId] — an unidentified widget
  /// participates in no lookup, which is a legitimate state and not a
  /// degenerate one. When non-null it is the scope-prefixed id:
  /// `'save'` at the top level, `'settings.save'` under a `settings` scope.
  ///
  /// Resource keys, authorization rules and group membership are all addressed
  /// by this path, which is why the two implementations have to produce the
  /// same string from the same inputs — a prefix that differs between them
  /// looks up a rule belonging to some other widget.
  String? get basePath;
}
