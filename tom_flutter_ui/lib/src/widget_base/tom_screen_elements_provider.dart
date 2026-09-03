import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Interface for screen element providers.
///
/// A screen element provider declares all widgets for a screen as typed fields
/// and provides a [scope] for resource/authorization lookups.
///
/// When used with `@tomReflect`, reflection discovers the field list
/// automatically — no manual element registration needed.
///
/// This is an interface rather than a base class because element
/// providers must be `@tomReflect`-annotated and the reflection annotation
/// works on any class. The interface restricts the generic type on
/// [TomAclBuilder] to classes explicitly intended as element providers.
///
/// ```dart
/// @tomReflect
/// class LoginScreenElements implements TomScreenElementsProvider {
///   @override
///   final TomScope scope;
///
///   LoginScreenElements({required this.scope});
///
///   late final TomText greeting = TomText(tomId: 'login_greeting');
///   late final TomButton loginButton = TomButton(tomId: 'login_button', ...);
/// }
/// ```
abstract interface class TomScreenElementsProvider {
  /// The scope for resource and authorization lookups.
  ///
  /// This scope provides the base path for all widgets in this provider.
  /// When widgets resolve their resource paths, they use this scope's path
  /// as a prefix.
  ///
  /// Typically set during construction, e.g., `TomScope.named('loginScreen')`.
  TomScope get scope;
}

/// Base class for screen element providers that is itself a [TomScope].
///
/// Extend this class to declare reusable, scoped widget trees that are
/// created once and returned on every rebuild. Because the class IS a
/// [TomScope], pass `scope: this` on child widgets to nest them under
/// this provider's scope path.
///
/// Nesting providers chains the scopes automatically:
///
/// ```dart
/// // Outer provider (created inside a TomScope zone for "demo23")
/// class OrderScreenProvider extends TomScreenElementsProviderBase {
///   OrderScreenProvider([TomScreenElementsProvider? parent])
///       : super('order', parent);
///
///   late final submitButton = TomButton(tomId: 'submit', scope: this);
///   late final details = OrderDetailsProvider(this);
/// }
///
/// // Nested provider
/// class OrderDetailsProvider extends TomScreenElementsProviderBase {
///   OrderDetailsProvider(TomScreenElementsProvider parent)
///       : super('details', parent);
///
///   late final nameField = TomTextField(tomId: 'name', scope: this);
/// }
/// ```
///
/// With the outer zone scope "demo23", the resulting resource paths are:
/// - `demo23.order.submit`
/// - `demo23.order.details.name`
class TomScreenElementsProviderBase
    with TomScopeMixin
    implements TomScreenElementsProvider {
  /// Creates a scoped element provider.
  ///
  /// [scopeId] — the scope segment for this provider (e.g., `'basicSection'`).
  /// When `null`, the provider adopts the current scope without creating a
  /// child scope. This is useful for root providers that run inside an
  /// existing [TomScope.withScope] zone.
  ///
  /// [parent] — optional parent provider. When given, this provider's scope
  /// nests under `parent.scope`. When omitted, nests under the current zone
  /// scope ([TomScope.current]).
  TomScreenElementsProviderBase([
    String? scopeId,
    TomScreenElementsProvider? parent,
  ]) {
    final parentScope = parent?.scope ?? TomScope.current;
    if (scopeId != null) {
      initScope(scopeId: scopeId, parentScope: parentScope);
    } else {
      // Adopt the parent scope without nesting
      initScope(scopeId: parentScope.id, parentScope: parentScope.parent);
    }
  }

  @override
  TomScope get scope => this;
}
